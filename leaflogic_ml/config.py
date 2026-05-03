"""Training / inference hyperparameters and paths."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class TrainConfig:
    """Paths must point to a directory that contains ``train/`` and ``valid/`` class subfolders."""

    dataset_root: Path
    output_dir: Path = field(default_factory=lambda: Path("runs") / "default")
    image_size: int = 256
    batch_size: int = 32
    epochs: int = 5
    max_lr: float = 0.01
    weight_decay: float = 0.0
    grad_clip: float | None = None
    num_workers: int = 0
    seed: int = 42
    device: str | None = None  # "cuda", "cpu", or None = auto
