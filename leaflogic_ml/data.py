"""ImageFolder loaders + transforms (fixed size for the CNN)."""

from __future__ import annotations

from pathlib import Path

import torch
from torch.utils.data import DataLoader
from torchvision import transforms
from torchvision.datasets import ImageFolder

from leaflogic_ml.config import TrainConfig


def build_transforms(image_size: int, train: bool) -> transforms.Compose:
    if train:
        return transforms.Compose(
            [
                transforms.RandomHorizontalFlip(),
                transforms.Resize((image_size, image_size)),
                transforms.ToTensor(),
            ]
        )
    return transforms.Compose(
        [
            transforms.Resize((image_size, image_size)),
            transforms.ToTensor(),
        ]
    )


def build_dataloaders(cfg: TrainConfig) -> tuple[DataLoader, DataLoader, list[str]]:
    root = cfg.dataset_root.resolve()
    train_dir = root / "train"
    valid_dir = root / "valid"
    if not train_dir.is_dir():
        raise FileNotFoundError(f"Missing train folder: {train_dir}")
    if not valid_dir.is_dir():
        raise FileNotFoundError(f"Missing valid folder: {valid_dir}")

    train_ds = ImageFolder(str(train_dir), transform=build_transforms(cfg.image_size, train=True))
    valid_ds = ImageFolder(str(valid_dir), transform=build_transforms(cfg.image_size, train=False))

    if train_ds.classes != valid_ds.classes:
        raise ValueError("train and valid class folders do not match; check dataset layout.")

    train_loader = DataLoader(
        train_ds,
        batch_size=cfg.batch_size,
        shuffle=True,
        num_workers=cfg.num_workers,
        pin_memory=torch.cuda.is_available(),
    )
    valid_loader = DataLoader(
        valid_ds,
        batch_size=cfg.batch_size,
        shuffle=False,
        num_workers=cfg.num_workers,
        pin_memory=torch.cuda.is_available(),
    )
    return train_loader, valid_loader, train_ds.classes
