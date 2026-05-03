"""Training loop (OneCycleLR) from the notebook template."""

from __future__ import annotations

import torch
import torch.nn as nn
from torch.optim import Optimizer

from leaflogic_ml.model_arch import ImageClassificationBase


def get_lr(optimizer: Optimizer) -> float:
    for param_group in optimizer.param_groups:
        return float(param_group["lr"])
    return 0.0


@torch.no_grad()
def evaluate(model: ImageClassificationBase, val_loader, *, log_batches: bool = False) -> dict:
    model.eval()
    if log_batches:
        n = len(val_loader)
        print(f"  validation: {n} batches...", flush=True)
    outputs = []
    for step, batch in enumerate(val_loader, start=1):
        outputs.append(model.validation_step(batch))
        if log_batches and step % max(1, len(val_loader) // 10) == 0:
            print(f"    val batch {step}/{len(val_loader)}", flush=True)
    return model.validation_epoch_end(outputs)


def _snapshot_state_dict(model: torch.nn.Module) -> dict[str, torch.Tensor]:
    return {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}


def fit_one_cycle(
    epochs: int,
    max_lr: float,
    model: ImageClassificationBase,
    train_loader,
    val_loader,
    weight_decay: float = 0.0,
    grad_clip: float | None = None,
    opt_func=torch.optim.SGD,
    best_tracker: dict | None = None,
    *,
    log_every: int | None = 100,
    max_train_batches_per_epoch: int | None = None,
) -> list[dict]:
    if torch.cuda.is_available():
        torch.cuda.empty_cache()

    n_loader_batches = len(train_loader)
    steps_per_epoch = (
        n_loader_batches
        if not max_train_batches_per_epoch
        else min(n_loader_batches, max_train_batches_per_epoch)
    )
    if max_train_batches_per_epoch and steps_per_epoch < n_loader_batches:
        print(
            f"Note: training only {steps_per_epoch}/{n_loader_batches} batches per epoch "
            f"(faster smoke runs; full-data training removes --max-train-batches).",
            flush=True,
        )

    history: list[dict] = []
    optimizer = opt_func(model.parameters(), max_lr, weight_decay=weight_decay)
    # OneCycle total steps must match actual optimizer steps each epoch.
    sched = torch.optim.lr_scheduler.OneCycleLR(
        optimizer,
        max_lr,
        epochs=epochs,
        steps_per_epoch=steps_per_epoch,
    )

    for epoch in range(epochs):
        print(
            f"Epoch {epoch + 1}/{epochs}: training {steps_per_epoch} batches "
            f"(of {n_loader_batches} in loader; CPU time scales with batch count)...",
            flush=True,
        )
        model.train()
        train_losses: list[torch.Tensor] = []
        lrs: list[float] = []
        for step, batch in enumerate(train_loader, start=1):
            loss = model.training_step(batch)
            train_losses.append(loss)
            loss.backward()
            if grad_clip is not None:
                nn.utils.clip_grad_value_(model.parameters(), grad_clip)
            optimizer.step()
            optimizer.zero_grad()
            lrs.append(get_lr(optimizer))
            sched.step()
            if log_every and step % log_every == 0:
                tail = train_losses[-log_every:]
                avg = torch.stack(tail).mean().item()
                print(
                    f"  batch {step}/{steps_per_epoch}  loss={loss.detach().item():.4f}  "
                    f"last_{len(tail)}_avg={avg:.4f}",
                    flush=True,
                )
            if step >= steps_per_epoch:
                break

        result = evaluate(model, val_loader, log_batches=log_every is not None and log_every > 0)
        result["train_loss"] = torch.stack(train_losses).mean().item()
        result["lrs"] = lrs
        model.epoch_end(epoch, result)
        history.append(result)

        if best_tracker is not None:
            va = result["val_acc"]
            if va > best_tracker.get("best_val_acc", -1.0):
                best_tracker["best_val_acc"] = va
                best_tracker["best_epoch"] = epoch
                best_tracker["state_dict"] = _snapshot_state_dict(model)

    return history
