"""
Train plant-disease classifier (ImageFolder: ``dataset_root/train`` and ``dataset_root/valid``).

Usage (from repo root ``MAD``)::

    python -m leaflogic_ml.train --dataset-root \"C:/data/New Plant Diseases Dataset(Augmented)/New Plant Diseases Dataset(Augmented)\"

After Kaggle unzip, ``dataset_root`` is usually the *inner* folder that directly contains ``train`` and ``valid``.
"""

from __future__ import annotations

import argparse
import random
import sys
from pathlib import Path

import numpy as np
import torch

from leaflogic_ml.checkpoint import save_checkpoint
from leaflogic_ml.config import TrainConfig
from leaflogic_ml.data import build_dataloaders
from leaflogic_ml.model_arch import CNNNeuralNet, DeviceDataLoader, to_device
from leaflogic_ml.train_loop import evaluate, fit_one_cycle


def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Train LeafLogic CNN on plant disease ImageFolder data.")
    p.add_argument(
        "--dataset-root",
        type=Path,
        required=True,
        help="Folder that contains train/ and valid/ subdirectories (class names = subfolder names).",
    )
    p.add_argument("--output-dir", type=Path, default=Path("leaflogic_ml") / "runs" / "latest")
    p.add_argument("--image-size", type=int, default=256, help="Must stay 256 for this CNN architecture.")
    p.add_argument("--batch-size", type=int, default=32)
    p.add_argument("--epochs", type=int, default=5)
    p.add_argument("--max-lr", type=float, default=0.01)
    p.add_argument("--weight-decay", type=float, default=0.0)
    p.add_argument("--grad-clip", type=float, default=None)
    p.add_argument("--num-workers", type=int, default=0, help="Use 0 on Windows unless you use proper main guard.")
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--device", type=str, default=None, choices=[None, "cpu", "cuda"])
    p.add_argument(
        "--log-every",
        type=int,
        default=100,
        metavar="N",
        help="Print training progress every N batches (0 = epoch summary only). Default 100.",
    )
    p.add_argument(
        "--max-train-batches",
        type=int,
        default=None,
        metavar="N",
        help=(
            "If set, stop each epoch after N training batches (mini-batches are already the default; "
            "this caps how many you run per epoch for quick tests). Full training: omit this flag."
        ),
    )
    return p.parse_args()


def main() -> None:
    args = parse_args()
    if hasattr(sys.stdout, "reconfigure"):
        try:
            sys.stdout.reconfigure(line_buffering=True)
        except (OSError, ValueError):
            pass

    cfg = TrainConfig(
        dataset_root=args.dataset_root,
        output_dir=args.output_dir,
        image_size=args.image_size,
        batch_size=args.batch_size,
        epochs=args.epochs,
        max_lr=args.max_lr,
        weight_decay=args.weight_decay,
        grad_clip=args.grad_clip,
        num_workers=args.num_workers,
        seed=args.seed,
        device=args.device,
    )

    if cfg.image_size % 256 != 0:
        raise ValueError("image_size must be divisible by 256 for this CNN (default: 256).")

    if args.max_train_batches is not None and args.max_train_batches < 1:
        raise SystemExit("--max-train-batches must be a positive integer, or omit it for full epochs.")

    set_seed(cfg.seed)
    device_str = cfg.device or ("cuda" if torch.cuda.is_available() else "cpu")
    device = torch.device(device_str)

    train_loader, valid_loader, class_names = build_dataloaders(cfg)
    print(
        f"Device: {device}, classes: {len(class_names)}\n"
        f"Train samples: {len(train_loader.dataset)}, batches/epoch: {len(train_loader)}\n"
        f"Valid samples: {len(valid_loader.dataset)}, batches: {len(valid_loader)}",
        flush=True,
    )

    train_loader = DeviceDataLoader(train_loader, device)
    valid_loader = DeviceDataLoader(valid_loader, device)

    model = CNNNeuralNet(3, len(class_names))
    model = to_device(model, device)

    log_every = args.log_every if args.log_every > 0 else None
    best_tracker: dict = {"best_val_acc": -1.0, "best_epoch": -1, "state_dict": None}
    history = fit_one_cycle(
        cfg.epochs,
        cfg.max_lr,
        model,
        train_loader,
        valid_loader,
        weight_decay=cfg.weight_decay,
        grad_clip=cfg.grad_clip,
        best_tracker=best_tracker,
        log_every=log_every,
        max_train_batches_per_epoch=args.max_train_batches,
    )

    cfg.output_dir.mkdir(parents=True, exist_ok=True)
    last_path = cfg.output_dir / "last.pt"
    save_checkpoint(
        last_path,
        model.state_dict(),
        class_names,
        cfg.image_size,
        extra={"history": history},
    )

    best_val = float(best_tracker["best_val_acc"])
    best_epoch = int(best_tracker["best_epoch"])
    best_state = best_tracker["state_dict"]
    print(f"Best val_acc {best_val:.4f} at epoch {best_epoch}", flush=True)
    if best_state is None:
        best_state = model.state_dict()
    save_checkpoint(
        cfg.output_dir / "best.pt",
        best_state,
        class_names,
        cfg.image_size,
        extra={"best_epoch": best_epoch, "best_val_acc": best_val},
    )

    final_metrics = evaluate(model, valid_loader, log_batches=False)
    print("Final validation:", final_metrics, flush=True)


if __name__ == "__main__":
    main()
