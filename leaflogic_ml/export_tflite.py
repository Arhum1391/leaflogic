"""
Export ``CNNNeuralNet`` checkpoint (``best.pt`` / ``last.pt``) to TensorFlow Lite.

Uses ONNX as an intermediate format (recommended separate venv if ``tensorflow``
conflicts with your ``torch`` install)::

    pip install onnx onnx2tf tensorflow
    python -m leaflogic_ml.export_tflite --checkpoint leaflogic_ml/runs/smoke/best.pt \\
        --out-dir ..\\leaflogic\\assets\\ml

Writes ``leaf_classifier.tflite`` and ``labels.json`` for the Flutter app.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import torch
import torch.nn as nn

from leaflogic_ml.checkpoint import load_checkpoint
from leaflogic_ml.model_arch import CNNNeuralNet


class NormalizingWrapper(nn.Module):
    """Bakes (x - mean) / std into the exported graph so the Flutter app can
    feed plain [0, 1] RGB tensors without knowing the training normalization."""

    def __init__(self, inner: nn.Module, mean: list[float], std: list[float]):
        super().__init__()
        self.inner = inner
        self.register_buffer("mean", torch.tensor(mean).view(1, 3, 1, 1))
        self.register_buffer("std", torch.tensor(std).view(1, 3, 1, 1))

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.inner((x - self.mean) / self.std)


def build_model_from_checkpoint(ckpt: dict) -> nn.Module:
    extra = ckpt.get("extra") or {}
    arch = extra.get("model_arch", "cnn_custom")
    class_names: list[str] = ckpt["class_names"]
    n = len(class_names)

    if arch == "cnn_custom":
        model = CNNNeuralNet(3, n)
        model.load_state_dict(ckpt["model_state"])
        model.eval()
        return model

    if arch == "mobilenet_v3_small":
        from torchvision.models import mobilenet_v3_small

        backbone = mobilenet_v3_small(weights=None)
        in_features = backbone.classifier[-1].in_features
        backbone.classifier[-1] = nn.Linear(in_features, n)
        backbone.load_state_dict(ckpt["model_state"])
        backbone.eval()
        norm = extra.get("normalization") or {"mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]}
        return NormalizingWrapper(backbone, norm["mean"], norm["std"]).eval()

    if arch == "efficientnet_b0":
        from torchvision.models import efficientnet_b0

        backbone = efficientnet_b0(weights=None)
        in_features = backbone.classifier[-1].in_features
        backbone.classifier[-1] = nn.Linear(in_features, n)
        backbone.load_state_dict(ckpt["model_state"])
        backbone.eval()
        norm = extra.get("normalization") or {"mean": [0.485, 0.456, 0.406], "std": [0.229, 0.224, 0.225]}
        return NormalizingWrapper(backbone, norm["mean"], norm["std"]).eval()

    raise ValueError(f"Unknown model_arch in checkpoint: {arch!r}")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Export PyTorch checkpoint to TFLite.")
    p.add_argument("--checkpoint", type=Path, required=True)
    p.add_argument(
        "--out-dir",
        type=Path,
        required=True,
        help="Flutter assets folder, e.g. leaflogic/assets/ml",
    )
    p.add_argument("--image-size", type=int, default=256)
    return p.parse_args()


def main() -> None:
    args = parse_args()
    ckpt_path = args.checkpoint.resolve()
    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    ckpt = load_checkpoint(ckpt_path, map_location="cpu")
    class_names: list[str] = ckpt["class_names"]
    image_size = int(ckpt.get("image_size", args.image_size))

    model = build_model_from_checkpoint(ckpt)

    dummy = torch.randn(1, 3, image_size, image_size, dtype=torch.float32)

    with tempfile.TemporaryDirectory(prefix="leaflogic_onnx_") as td:
        td_path = Path(td)
        onnx_path = td_path / "model.onnx"
        sm_path = td_path / "saved_model"

        print("Exporting ONNX...", flush=True)
        torch.onnx.export(
            model,
            dummy,
            str(onnx_path),
            input_names=["input"],
            output_names=["output"],
            opset_version=17,
            do_constant_folding=True,
            dynamic_axes={"input": {0: "batch"}, "output": {0: "batch"}},
        )

        print("Converting ONNX -> SavedModel (onnx2tf)...", flush=True)
        r = subprocess.run(
            ["onnx2tf", "-i", str(onnx_path), "-o", str(sm_path)],
            check=False,
        )
        if r.returncode != 0:
            r = subprocess.run(
                [sys.executable, "-m", "onnx2tf", "-i", str(onnx_path), "-o", str(sm_path)],
                check=False,
            )
        if r.returncode != 0:
            raise SystemExit(
                "onnx2tf failed. In a venv with enough disk space:\n"
                "  pip install onnx onnx2tf tensorflow-cpu\n"
                "Then re-run this script (torch can stay in a different env for training)."
            )

        print("Converting SavedModel -> TFLite...", flush=True)
        import tensorflow as tf

        converter = tf.lite.TFLiteConverter.from_saved_model(str(sm_path))
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        tflite_buf = converter.convert()

    tflite_out = out_dir / "leaf_classifier.tflite"
    tflite_out.write_bytes(tflite_buf)
    labels_out = out_dir / "labels.json"
    labels_out.write_text(json.dumps(class_names, indent=2), encoding="utf-8")

    print(f"Wrote {tflite_out} ({len(tflite_buf) // 1024} KiB)", flush=True)
    print(f"Wrote {labels_out} ({len(class_names)} classes)", flush=True)


if __name__ == "__main__":
    main()
