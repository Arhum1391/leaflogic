"""
Run inference with a checkpoint produced by ``leaflogic_ml.train``.

Usage::

    python -m leaflogic_ml.predict --checkpoint leaflogic_ml/runs/latest/best.pt --image path/to/leaf.jpg --top-k 5
    python -m leaflogic_ml.predict --checkpoint .../best.pt --image-dir path/to/folder
"""

from __future__ import annotations

import argparse
from pathlib import Path

import torch
from PIL import Image
from torchvision import transforms

from leaflogic_ml.checkpoint import load_checkpoint
from leaflogic_ml.model_arch import CNNNeuralNet, to_device


def build_eval_transform(image_size: int) -> transforms.Compose:
    return transforms.Compose(
        [
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
        ]
    )


@torch.no_grad()
def predict_tensor(
    model: CNNNeuralNet,
    x: torch.Tensor,
    class_names: list[str],
    top_k: int,
) -> list[tuple[str, float]]:
    """x shape [1,3,H,W] on same device as model."""
    logits = model(x)
    probs = torch.softmax(logits, dim=1)[0]
    k = min(top_k, probs.shape[0])
    top = torch.topk(probs, k)
    return [(class_names[i], float(top.values[j])) for j, i in enumerate(top.indices.tolist())]


def load_model_for_inference(checkpoint_path: Path, device: torch.device) -> tuple[CNNNeuralNet, list[str], int]:
    ckpt = load_checkpoint(checkpoint_path, map_location=device)
    class_names: list[str] = ckpt["class_names"]
    image_size: int = int(ckpt["image_size"])
    model = CNNNeuralNet(3, len(class_names))
    model.load_state_dict(ckpt["model_state"])
    model.to(device)
    model.eval()
    return model, class_names, image_size


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Predict plant disease class from one or more images.")
    p.add_argument("--checkpoint", type=Path, required=True, help="Path to best.pt or last.pt")
    g = p.add_mutually_exclusive_group(required=True)
    g.add_argument("--image", type=Path, default=None, help="Single image path")
    g.add_argument(
        "--image-dir",
        type=Path,
        default=None,
        help="Folder of images (*.jpg, *.jpeg, *.png); prints one block per file",
    )
    p.add_argument("--top-k", type=int, default=5)
    p.add_argument("--device", type=str, default=None, choices=[None, "cpu", "cuda"])
    return p.parse_args()


def _iter_images(image_dir: Path) -> list[Path]:
    exts = {".jpg", ".jpeg", ".png", ".webp", ".JPG", ".JPEG", ".PNG"}
    return sorted(p for p in image_dir.iterdir() if p.suffix in exts)


def main() -> None:
    args = parse_args()
    device_str = args.device or ("cuda" if torch.cuda.is_available() else "cpu")
    device = torch.device(device_str)

    model, class_names, image_size = load_model_for_inference(args.checkpoint.resolve(), device)
    tfm = build_eval_transform(image_size)

    paths: list[Path]
    if args.image is not None:
        paths = [args.image]
    else:
        paths = _iter_images(args.image_dir.resolve())
        if not paths:
            raise SystemExit(f"No images found in {args.image_dir}")

    for path in paths:
        img = Image.open(path).convert("RGB")
        x = tfm(img).unsqueeze(0)
        x = to_device(x, device)
        ranked = predict_tensor(model, x, class_names, args.top_k)
        print(f"\n== {path.name} ==")
        for name, prob in ranked:
            print(f"  {prob*100:5.2f}%  {name}")


if __name__ == "__main__":
    main()
