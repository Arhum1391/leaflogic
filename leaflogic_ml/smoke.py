"""
End-to-end smoke test: tiny dataset → short train → one prediction.

From repo root (``MAD``)::

    python -m leaflogic_ml.smoke

Requires the full dataset at the default relative path, or pass ``--source``.

Prints a sample ``flutter run`` line with ``MOCK_DIAGNOSIS`` so the app dashboard
matches how a real top-1 prediction will look until TFLite is wired.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

from leaflogic_ml.smoke_data import build_smoke_dataset


def _default_source() -> Path:
    return (
        Path.cwd()
        / "New Plant Diseases Dataset(Augmented)"
        / "New Plant Diseases Dataset(Augmented)"
    )


def _first_valid_image(root: Path) -> Path:
    valid = root / "valid"
    for cls_dir in sorted(p for p in valid.iterdir() if p.is_dir()):
        imgs = sorted(
            p
            for p in cls_dir.iterdir()
            if p.is_file() and p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}
        )
        if imgs:
            return imgs[0]
    raise FileNotFoundError(f"No images under {valid}")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Smoke: tiny dataset + train + predict + Flutter hint.")
    p.add_argument("--source", type=Path, default=None, help="Inner dataset root (train/ + valid/).")
    p.add_argument(
        "--dest",
        type=Path,
        default=Path("leaflogic_ml") / "_smoke_dataset",
        help="Tiny dataset output (removed and recreated each run).",
    )
    p.add_argument("--run-dir", type=Path, default=Path("leaflogic_ml") / "runs" / "smoke")
    p.add_argument("--max-classes", type=int, default=5)
    p.add_argument("--train-per-class", type=int, default=2)
    p.add_argument("--valid-per-class", type=int, default=1)
    return p.parse_args()


def main() -> None:
    args = parse_args()
    source = args.source or _default_source()
    if not source.is_dir():
        raise SystemExit(
            f"Dataset not found at {source.resolve()}.\n"
            "Pass --source to your inner folder that contains train/ and valid/."
        )

    dest = args.dest
    run_dir = args.run_dir
    run_dir.mkdir(parents=True, exist_ok=True)

    print("== 1/3 Build tiny dataset ==", flush=True)
    names = build_smoke_dataset(
        source,
        dest,
        max_classes=args.max_classes,
        train_per_class=args.train_per_class,
        valid_per_class=args.valid_per_class,
        seed=42,
    )
    print(f"   Classes: {names}", flush=True)

    print("\n== 2/3 Train (few steps, CPU) ==", flush=True)
    dest_res = dest.resolve()
    run_res = run_dir.resolve()
    cmd = [
        sys.executable,
        "-m",
        "leaflogic_ml.train",
        "--dataset-root",
        str(dest_res),
        "--output-dir",
        str(run_res),
        "--epochs",
        "2",
        "--batch-size",
        "4",
        "--max-train-batches",
        "32",
        "--log-every",
        "4",
        "--device",
        "cpu",
    ]
    print(" ", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True, cwd=Path.cwd())

    print("\n== 3/3 Predict one validation image ==", flush=True)
    sample = _first_valid_image(dest_res)
    ckpt = run_res / "best.pt"
    if not ckpt.is_file():
        ckpt = run_res / "last.pt"
    pred_cmd = [
        sys.executable,
        "-m",
        "leaflogic_ml.predict",
        "--checkpoint",
        str(ckpt),
        "--image",
        str(sample),
        "--top-k",
        "3",
        "--device",
        "cpu",
    ]
    print(" ", " ".join(pred_cmd), flush=True)
    proc = subprocess.run(pred_cmd, check=True, capture_output=True, text=True, cwd=Path.cwd())
    print(proc.stdout, end="", flush=True)
    if proc.stderr:
        print(proc.stderr, end="", flush=True)

    # Parse first "NN.NN%  class_name" line from predict stdout
    top_label = ""
    top_conf = 0.0
    for line in proc.stdout.splitlines():
        s = line.strip()
        if not s or "%" not in s or not s[0].isdigit():
            continue
        try:
            pct_part, _, label_part = s.partition("%")
            top_conf = float(pct_part.strip()) / 100.0
            top_label = label_part.strip()
            if top_label:
                break
        except ValueError:
            continue

    if not top_label:
        top_label = names[0] if names else "Unknown_class"
        top_conf = 0.5

    species_guess, _, disease_rest = top_label.partition("___")
    if not disease_rest:
        species_guess = "Plant"
        disease_rest = top_label

    print("\n== App UI preview (mock diagnosis card) ==", flush=True)
    print(
        "The real app will show this after you export TFLite and wire inference. "
        "For now, run Flutter with MOCK_DIAGNOSIS to mirror the layout:\n",
        flush=True,
    )
    # Escape for Windows cmd/PowerShell user copy-paste - use single quotes in PowerShell for dart-define values with spaces
    conf_str = f"{top_conf:.4f}" if top_conf else "0.5"
    safe_species = species_guess.replace('"', "")
    safe_disease = disease_rest.replace('"', "")
    print(
        "PowerShell (from leaflogic folder), add your Supabase defines as usual:\n",
        flush=True,
    )
    print(
        "  flutter run "
        "--dart-define=MOCK_DIAGNOSIS=true "
        f'--dart-define=MOCK_SPECIES="{safe_species}" '
        f'--dart-define=MOCK_DISEASE="{safe_disease}" '
        f"--dart-define=MOCK_CONFIDENCE={conf_str}",
        flush=True,
    )

    print("\n== Export real TFLite for the app (separate venv with disk space) ==", flush=True)
    print(
        "  pip install -r leaflogic_ml/requirements_export.txt\n"
        f"  python -m leaflogic_ml.export_tflite --checkpoint {ckpt} "
        r"--out-dir leaflogic\assets\ml",
        flush=True,
    )


if __name__ == "__main__":
    main()
