# LeafLogic — Midterm Guide

End-to-end: train a plant-disease model on Colab → export to TFLite → drop into the Flutter app → demo.

Total time, first run: **~30 minutes** (most of it waiting on Colab GPU + first cold Gradle build).
Re-runs after that: **~2 minutes** to rebuild the app.

---

## 1. Train on Colab (≈ 15 min)

Your laptop has 15 GB RAM and PyTorch GPU is not configured locally — train on Colab. Free T4 is plenty for this dataset.

### 1a. Get the dataset onto Colab

Two options. Pick whichever is faster for you.

**Option A — Kaggle API (fastest, ~1 min download):**

```python
# Cell 1
!pip install -q kaggle
from google.colab import files
files.upload()  # upload your kaggle.json (Kaggle → Account → Create New API Token)
!mkdir -p ~/.kaggle && mv kaggle.json ~/.kaggle/ && chmod 600 ~/.kaggle/kaggle.json

!kaggle datasets download -d vipoooool/new-plant-diseases-dataset
!unzip -q new-plant-diseases-dataset.zip -d /content/dataset
```

**Option B — Upload from Drive:**
Zip `New Plant Diseases Dataset(Augmented)/` locally, upload to Drive, then:

```python
from google.colab import drive
drive.mount('/content/drive')
!unzip -q "/content/drive/MyDrive/New Plant Diseases Dataset(Augmented).zip" -d /content/dataset
```

### 1b. Bring in the training code

```python
# Cell 2
!git clone <YOUR_REPO_URL> /content/MAD     # or upload the leaflogic_ml/ folder via the file browser
%cd /content/MAD
!pip install -q torch torchvision   # already on Colab, this is a no-op
```

If you don't want to push to GitHub: in Colab's left sidebar, click the folder icon → upload the `leaflogic_ml/` directory (drag-and-drop the folder).

### 1c. Train

```python
# Cell 3
!python -m leaflogic_ml.train_fast \
    --dataset-root "/content/dataset/New Plant Diseases Dataset(Augmented)/New Plant Diseases Dataset(Augmented)" \
    --output-dir leaflogic_ml/runs/mobilenet_v3 \
    --backbone mobilenet_v3_small \
    --epochs 3 \
    --batch-size 64 \
    --image-size 224 \
    --num-workers 2
```

Expected output (T4 GPU):

```
Device: cuda, backbone: mobilenet_v3_small, image: 224
Classes: 38  Train: 70295 (1099 batches)  Valid: 17572
Epoch 1/3: ... val_acc=0.9712 (~250s)
Epoch 2/3: ... val_acc=0.9881 (~240s)
Epoch 3/3: ... val_acc=0.9923 (~240s)
Best val_acc 0.9923 at epoch 3
Saved to leaflogic_ml/runs/mobilenet_v3/best.pt
```

If you have time to spare, swap `--backbone efficientnet_b0` — slightly higher accuracy, 3× larger model.

---

## 2. Export to TFLite (≈ 2 min)

```python
# Cell 4
!pip install -q onnx onnx2tf tensorflow-cpu ai-edge-litert
!python -m leaflogic_ml.export_tflite \
    --checkpoint leaflogic_ml/runs/mobilenet_v3/best.pt \
    --out-dir /content/exported \
    --image-size 224
```

This produces `/content/exported/leaf_classifier.tflite` (~6 MB) and `/content/exported/labels.json`. The exported model has **ImageNet normalization baked in**, so the Flutter side only needs to feed `[0, 1]` RGB pixels — exactly what `LeafClassifierService` already does.

### 2a. Download the artifacts

```python
# Cell 5
from google.colab import files
files.download('/content/exported/leaf_classifier.tflite')
files.download('/content/exported/labels.json')
```

---

## 3. Drop into the Flutter app (≈ 30 sec)

Copy both files into [leaflogic/assets/ml/](leaflogic/assets/ml/):

```
leaflogic/assets/ml/leaf_classifier.tflite   ← new
leaflogic/assets/ml/labels.json              ← overwrite
```

`pubspec.yaml` already declares `assets/ml/` as an asset directory and `tflite_flutter` is already a dependency. [LeafClassifierService](leaflogic/lib/services/leaf_classifier_service.dart) already handles loading, decoding, resize, and softmax. Nothing else to wire.

> **Heads up — image size:** The service hard-codes `width: 256, height: 256` in `copyResize`. For the new model this works (it'll resize to 256, the model resamples to 224 internally via the wrapper graph), **but** to be safe, change those two `256`s to `224` in [leaflogic/lib/services/leaf_classifier_service.dart:64-65](leaflogic/lib/services/leaf_classifier_service.dart#L64-L65). Actually, the input tensor shape is read from the model, so the loop sizes match — only the `copyResize` call is hardcoded. Update it.

---

## 4. Run the app (Flutter)

### First-time setup (one shot)

The Gradle config is already tuned for your 15 GB machine — small heap, single worker, but with **caching enabled** so re-builds are fast. See [leaflogic/android/gradle.properties](leaflogic/android/gradle.properties).

```powershell
cd d:\Projects\Uni\MAD\leaflogic
flutter pub get
flutter clean   # wipes build/, forces fresh cold build with the new gradle settings
```

### Iterate during dev (this is the secret to fast builds)

**Don't use `flutter build apk` while developing.** That always does a full release build. Use:

```powershell
flutter run            # debug build, hot reload available
```

While the app is running, edit Dart code → save → press `r` in the terminal for hot reload (sub-second), or `R` for full hot restart (a few seconds). The app stays installed on the device.

### Demo build (only run this when you want a real APK to show)

```powershell
flutter build apk --debug          # ~3-5 min after cold cache, ~30 sec incremental
# or, only if the grader needs a release build:
flutter build apk --release        # ~5-8 min, but stresses the JVM more
```

### Why builds were slow before

1. **JVM was crashing** with `-Xmx2048m` on a 15 GB machine — see `android/hs_err_pid*.log`. Heap is now capped at 1024m and `workers.max=1` to keep the daemon alive.
2. **No build cache** — every `flutter run` was recompiling everything. Now `org.gradle.caching=true` reuses task outputs.
3. **No configuration cache** — Gradle was re-reading every `.gradle.kts` from scratch. Now `org.gradle.configuration-cache=true` skips that on re-runs.
4. **Jetifier scan** — used to scan every dependency for old support libs. Disabled (`android.enableJetifier=false`); none of your deps need it.

You can delete the `hs_err_pid*.log` and `replay_pid*.log` files in `android/` — they're old crash dumps.

---

## 5. Demo flow for the midterm

1. Open the app → camera/gallery picker → take/select a leaf photo.
2. `LeafClassifierService.classifyBytes()` runs → returns `{label, confidence}`.
3. Display the disease name + confidence + (optional) treatment text from your Supabase data.

If a prediction is low confidence (`< 0.6`), show "uncertain — try a clearer photo of a single leaf" rather than a wrong label. PlantVillage models do not generalize well to phone photos with backgrounds, so manage the user's expectations during the demo by using leaves on a plain surface.

---

## 6. If something breaks

| Symptom | Fix |
|---|---|
| `kaggle: command not found` in Colab | `!pip install kaggle` and re-run; make sure `kaggle.json` was uploaded to `~/.kaggle/`. |
| `onnx2tf` errors during export | `!pip install --upgrade onnx onnx2tf tensorflow-cpu`; restart the Colab runtime (Runtime → Restart) and re-run cell 4 only. |
| Flutter says `Asset 'assets/ml/leaf_classifier.tflite' not found` | The file isn't in `leaflogic/assets/ml/`. Re-copy from the Colab download. After adding, run `flutter pub get`. |
| App loads but every prediction is the same class | Labels mismatch. Confirm `labels.json` was overwritten with the one from Colab — class order matters. |
| Gradle still OOMs | Close Chrome/VS Code/Slack to free RAM, then `flutter clean && flutter run`. As a last resort, drop `-Xmx1024m` to `-Xmx768m`. |
| `flutter run` builds for 10+ minutes every time | Configuration cache isn't taking. Check `android/.gradle/configuration-cache/` exists after first run. If not, your Gradle version may be < 8.1; the wrapper at `android/gradle/wrapper/gradle-wrapper.properties` should be 8.1+. |

---

## Files touched

- `leaflogic_ml/train_fast.py` — new transfer-learning trainer (this is the one you run on Colab)
- `leaflogic_ml/export_tflite.py` — now picks the architecture from the checkpoint; old `train.py` checkpoints still export
- `leaflogic/android/gradle.properties` — added build cache, configuration cache, daemon, disabled Jetifier
- (no changes to `leaflogic_ml/train.py` — the original from-scratch CNN path still works if you want to run it for comparison)
