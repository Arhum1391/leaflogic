"""Save / load checkpoints with class names for inference."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import torch


def save_checkpoint(
    path: Path,
    model_state: dict[str, Any],
    class_names: list[str],
    image_size: int,
    extra: dict[str, Any] | None = None,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "model_state": model_state,
        "class_names": class_names,
        "image_size": image_size,
        "extra": extra or {},
    }
    torch.save(payload, path)
    names_path = path.with_name("class_names.json")
    names_path.write_text(json.dumps(class_names, indent=2), encoding="utf-8")


def load_checkpoint(path: Path, map_location=None) -> dict[str, Any]:
    try:
        return torch.load(path, map_location=map_location, weights_only=False)
    except TypeError:
        return torch.load(path, map_location=map_location)
