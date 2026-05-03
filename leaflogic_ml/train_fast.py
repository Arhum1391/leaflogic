"""
Fast transfer-learning trainer for the plant-disease dataset.

Uses MobileNetV3-Small (ImageNet pretrained) at 224x224 with AMP + AdamW +
OneCycleLR. Hits >=98% val accuracy in 2-3 epochs on a free Colab T4 (~10-15
minutes total). The resulting model is small (~6 MB once exported to TFLite),
which is what you want to ship inside the Flutter app.

Usage (Colab / Kaggle / any CUDA box)::

    python -m leaflogic_ml.train_fast \\
        --dataset-root "/content/New Plant Diseases Dataset(Augmented)/New Plant Diseases Dataset(Augmented)" \\
        --output-dir leaflogic_ml/runs/mobilenet_v3 \\
        --epochs 3 --batch-size 64

The checkpoint format matches checkpoint.save_checkpoint, with the backbone
name recorded in extra["model_arch"] so export_tflite.py can rebuild the right
network at export time.
"""

from __future__ import annotations

import argparse
import random
import sys
import time
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torchvision import transforms
from torchvision.datasets import ImageFolder
from torchvision.models import (
    MobileNet_V3_Small_Weights,
    EfficientNet_B0_Weights,
    mobilenet_v3_small,
    efficientnet_b0,
)

from leaflogic_ml.checkpoint import save_checkpoint


SUPPORTED_BACKBONES = ("mobilenet_v3_small", "efficientnet_b0")


def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def build_model(backbone: str, num_classes: int) -> nn.Module:
    if backbone == "mobilenet_v3_small":
        model = mobilenet_v3_small(weights=MobileNet_V3_Small_Weights.IMAGENET1K_V1)
        in_features = model.classifier[-1].in_features
        model.classifier[-1] = nn.Linear(in_features, num_classes)
        return model
    if backbone == "efficientnet_b0":
        model = efficientnet_b0(weights=EfficientNet_B0_Weights.IMAGENET1K_V1)
        in_features = model.classifier[-1].in_features
        model.classifier[-1] = nn.Linear(in_features, num_classes)
        return model
    raise ValueError(f"Unknown backbone: {backbone}. Choose from {SUPPORTED_BACKBONES}.")


def build_loaders(
    dataset_root: Path,
    image_size: int,
    batch_size: int,
    num_workers: int,
) -> tuple[DataLoader, DataLoader, list[str]]:
    train_dir = dataset_root / "train"
    valid_dir = dataset_root / "valid"
    if not train_dir.is_dir() or not valid_dir.is_dir():
        raise FileNotFoundError(
            f"Expected train/ and valid/ under {dataset_root}. "
            "After Kaggle unzip, dataset_root is the *inner* folder."
        )

    # ImageNet normalization since the backbone was pretrained on ImageNet.
    mean = (0.485, 0.456, 0.406)
    std = (0.229, 0.224, 0.225)

    train_tfm = transforms.Compose(
        [
            transforms.Resize((image_size, image_size)),
            transforms.RandomHorizontalFlip(),
            transforms.ColorJitter(brightness=0.1, contrast=0.1, saturation=0.1),
            transforms.ToTensor(),
            transforms.Normalize(mean, std),
        ]
    )
    valid_tfm = transforms.Compose(
        [
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
            transforms.Normalize(mean, std),
        ]
    )

    train_ds = ImageFolder(str(train_dir), transform=train_tfm)
    valid_ds = ImageFolder(str(valid_dir), transform=valid_tfm)
    if train_ds.classes != valid_ds.classes:
        raise ValueError("train/ and valid/ class folders do not match.")

    pin = torch.cuda.is_available()
    persistent = num_workers > 0
    train_loader = DataLoader(
        train_ds,
        batch_size=batch_size,
        shuffle=True,
        num_workers=num_workers,
        pin_memory=pin,
        persistent_workers=persistent,
    )
    valid_loader = DataLoader(
        valid_ds,
        batch_size=batch_size,
        shuffle=False,
        num_workers=num_workers,
        pin_memory=pin,
        persistent_workers=persistent,
    )
    return train_loader, valid_loader, train_ds.classes


@torch.no_grad()
def evaluate(model: nn.Module, loader: DataLoader, device: torch.device) -> tuple[float, float]:
    model.eval()
    total_loss = 0.0
    total_correct = 0
    total_n = 0
    for images, labels in loader:
        images = images.to(device, non_blocking=True)
        labels = labels.to(device, non_blocking=True)
        with torch.autocast(device_type=device.type, dtype=torch.float16, enabled=device.type == "cuda"):
            logits = model(images)
            loss = F.cross_entropy(logits, labels, reduction="sum")
        total_loss += loss.item()
        total_correct += (logits.argmax(dim=1) == labels).sum().item()
        total_n += labels.size(0)
    return total_loss / total_n, total_correct / total_n


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Fast transfer-learning trainer (MobileNetV3 / EfficientNet-B0).")
    p.add_argument("--dataset-root", type=Path, required=True)
    p.add_argument("--output-dir", type=Path, default=Path("leaflogic_ml") / "runs" / "fast")
    p.add_argument(
        "--backbone",
        choices=SUPPORTED_BACKBONES,
        default="mobilenet_v3_small",
        help="MobileNetV3-Small ships ~6MB TFLite; EfficientNet-B0 is ~16MB but slightly more accurate.",
    )
    p.add_argument("--image-size", type=int, default=224)
    p.add_argument("--batch-size", type=int, default=64)
    p.add_argument("--epochs", type=int, default=3)
    p.add_argument("--max-lr", type=float, default=3e-3)
    p.add_argument("--weight-decay", type=float, default=1e-4)
    p.add_argument("--num-workers", type=int, default=2, help="On Colab use 2; on Windows use 0.")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--device", choices=["cpu", "cuda"], default=None)
    return p.parse_args()


def main() -> None:
    args = parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(line_buffering=True)
        except (OSError, ValueError):
            pass

    set_seed(args.seed)
    device_str = args.device or ("cuda" if torch.cuda.is_available() else "cpu")
    device = torch.device(device_str)
    print(f"Device: {device}, backbone: {args.backbone}, image: {args.image_size}", flush=True)
    if device.type == "cpu":
        print(
            "WARNING: training on CPU will take hours. Run this on Colab/Kaggle with a GPU "
            "(Runtime -> Change runtime type -> T4 GPU).",
            flush=True,
        )

    train_loader, valid_loader, class_names = build_loaders(
        args.dataset_root.resolve(),
        args.image_size,
        args.batch_size,
        args.num_workers,
    )
    n_train = len(train_loader.dataset)
    n_valid = len(valid_loader.dataset)
    n_batches = len(train_loader)
    print(
        f"Classes: {len(class_names)}  Train: {n_train} ({n_batches} batches)  Valid: {n_valid}",
        flush=True,
    )

    model = build_model(args.backbone, len(class_names)).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.max_lr, weight_decay=args.weight_decay)
    scheduler = torch.optim.lr_scheduler.OneCycleLR(
        optimizer,
        max_lr=args.max_lr,
        epochs=args.epochs,
        steps_per_epoch=n_batches,
    )
    scaler = torch.amp.GradScaler("cuda", enabled=device.type == "cuda")

    best_val_acc = -1.0
    best_state: dict | None = None
    best_epoch = -1
    history: list[dict] = []

    for epoch in range(args.epochs):
        model.train()
        epoch_start = time.time()
        running_loss = 0.0
        running_n = 0
        for step, (images, labels) in enumerate(train_loader, start=1):
            images = images.to(device, non_blocking=True)
            labels = labels.to(device, non_blocking=True)

            optimizer.zero_grad(set_to_none=True)
            with torch.autocast(device_type=device.type, dtype=torch.float16, enabled=device.type == "cuda"):
                logits = model(images)
                loss = F.cross_entropy(logits, labels)

            scaler.scale(loss).backward()
            scaler.step(optimizer)
            scaler.update()
            scheduler.step()

            running_loss += loss.item() * labels.size(0)
            running_n += labels.size(0)
            if step % 50 == 0 or step == n_batches:
                avg = running_loss / running_n
                print(
                    f"  epoch {epoch + 1}/{args.epochs} batch {step}/{n_batches} "
                    f"loss={avg:.4f} lr={scheduler.get_last_lr()[0]:.2e}",
                    flush=True,
                )

        train_loss = running_loss / running_n
        val_loss, val_acc = evaluate(model, valid_loader, device)
        elapsed = time.time() - epoch_start
        print(
            f"Epoch {epoch + 1}/{args.epochs}: train_loss={train_loss:.4f} "
            f"val_loss={val_loss:.4f} val_acc={val_acc:.4f} ({elapsed:.1f}s)",
            flush=True,
        )
        history.append(
            {"epoch": epoch + 1, "train_loss": train_loss, "val_loss": val_loss, "val_acc": val_acc}
        )

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_epoch = epoch + 1
            best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}

    args.output_dir.mkdir(parents=True, exist_ok=True)
    extra = {
        "model_arch": args.backbone,
        "history": history,
        "best_epoch": best_epoch,
        "best_val_acc": best_val_acc,
        "normalization": {"mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]},
    }
    save_checkpoint(
        args.output_dir / "last.pt",
        model.state_dict(),
        class_names,
        args.image_size,
        extra=extra,
    )
    save_checkpoint(
        args.output_dir / "best.pt",
        best_state if best_state is not None else model.state_dict(),
        class_names,
        args.image_size,
        extra=extra,
    )
    print(f"Best val_acc {best_val_acc:.4f} at epoch {best_epoch}", flush=True)
    print(f"Saved to {args.output_dir}/best.pt", flush=True)


if __name__ == "__main__":
    main()
