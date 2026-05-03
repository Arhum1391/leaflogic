"""Build a tiny ImageFolder tree from the full plant-disease dataset (for smoke tests)."""

from __future__ import annotations

import argparse
import random
import shutil
from pathlib import Path

_IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


def _list_images(folder: Path) -> list[Path]:
    if not folder.is_dir():
        return []
    return sorted(
        p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in _IMAGE_SUFFIXES
    )


def build_smoke_dataset(
    source_root: Path,
    dest_root: Path,
    *,
    max_classes: int = 5,
    train_per_class: int = 2,
    valid_per_class: int = 1,
    seed: int = 42,
) -> list[str]:
    """
    Copy a small slice into ``dest_root/train`` and ``dest_root/valid``.

    Returns the list of class names included (same order as training).
    """
    source_root = source_root.resolve()
    train_src = source_root / "train"
    valid_src = source_root / "valid"
    if not train_src.is_dir() or not valid_src.is_dir():
        raise FileNotFoundError(
            f"Expected {train_src} and {valid_src} (ImageFolder layout)."
        )

    rng = random.Random(seed)
    classes = sorted([p.name for p in train_src.iterdir() if p.is_dir()])
    if not classes:
        raise FileNotFoundError(f"No class folders under {train_src}")

    picked = classes[:max_classes]
    dest_root = dest_root.resolve()
    if dest_root.exists():
        shutil.rmtree(dest_root)

    for cls in picked:
        ts = train_src / cls
        vs = valid_src / cls
        t_imgs = _list_images(ts)
        v_imgs = _list_images(vs)
        if len(t_imgs) < train_per_class or len(v_imgs) < valid_per_class:
            raise FileNotFoundError(
                f"Class {cls!r} needs at least {train_per_class} train and "
                f"{valid_per_class} valid images; got {len(t_imgs)} / {len(v_imgs)}."
            )

        rng.shuffle(t_imgs)
        rng.shuffle(v_imgs)
        t_pick = t_imgs[:train_per_class]
        v_pick = v_imgs[:valid_per_class]

        dt = dest_root / "train" / cls
        dv = dest_root / "valid" / cls
        dt.mkdir(parents=True, exist_ok=True)
        dv.mkdir(parents=True, exist_ok=True)

        for i, p in enumerate(t_pick):
            shutil.copy2(p, dt / f"smoke_{i}{p.suffix.lower()}")
        for i, p in enumerate(v_pick):
            shutil.copy2(p, dv / f"smoke_{i}{p.suffix.lower()}")

    return picked


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Create a tiny train/valid tree for smoke training.")
    p.add_argument(
        "--source",
        type=Path,
        required=True,
        help="Inner dataset root (folder that contains train/ and valid/).",
    )
    p.add_argument(
        "--dest",
        type=Path,
        default=Path("leaflogic_ml") / "_smoke_dataset",
        help="Output root (will be deleted if it already exists).",
    )
    p.add_argument("--max-classes", type=int, default=5)
    p.add_argument("--train-per-class", type=int, default=2)
    p.add_argument("--valid-per-class", type=int, default=1)
    p.add_argument("--seed", type=int, default=42)
    return p.parse_args()


def main() -> None:
    args = parse_args()
    names = build_smoke_dataset(
        args.source,
        args.dest,
        max_classes=args.max_classes,
        train_per_class=args.train_per_class,
        valid_per_class=args.valid_per_class,
        seed=args.seed,
    )
    print(f"Wrote smoke dataset to {args.dest.resolve()}", flush=True)
    print(f"Classes ({len(names)}): {', '.join(names)}", flush=True)


if __name__ == "__main__":
    main()
