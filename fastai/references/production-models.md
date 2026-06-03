# Production Models

Use this reference when the user is training, reviewing, or deploying a model that will be used beyond a notebook.

## Contents

- [Production Readiness Checklist](#production-readiness-checklist)
- [Environment And Versioning](#environment-and-versioning)
- [Data And Split Integrity](#data-and-split-integrity)
- [Training Controls](#training-controls)
- [Evaluation](#evaluation)
- [Serialization And Serving](#serialization-and-serving)
- [Security](#security)
- [Monitoring And Maintenance](#monitoring-and-maintenance)

## Production Readiness Checklist

Before calling a fastai model production-ready, verify:

- Versions are pinned and recorded: Python, fastai, torch, torchvision, CUDA/runtime, fastcore, fasttransform.
- The data pipeline is deterministic and testable.
- The validation/test split matches deployment risk and avoids leakage.
- Loss, output shape, activation/decoding, and metrics match the task.
- The model can resume training from checkpoints.
- The inference path uses the same transforms and vocab/category mappings as training.
- Exported artifacts are trusted and traceable.
- Operational limits are defined: input shape/size, batch size, latency, memory, failure modes.
- Monitoring covers data drift, prediction distribution, errors, and retraining triggers.

## Environment And Versioning

Record:

```bash
python --version
python -c "import fastai, torch, torchvision; print(fastai.__version__, torch.__version__, torchvision.__version__)"
python -m pip freeze
```

Rules:

- Pin fastai and PyTorch together; fastai 2.8.7 release notes allow PyTorch <3, but hardware-specific PyTorch wheels still matter.
- Use containers or lockfiles for reproducible training and serving.
- Keep notebooks for exploration, but put reusable transforms, label functions, model constructors, losses, and metrics in importable modules.
- Treat Colab/Kaggle environments as exploratory unless dependencies and artifacts are pinned.

## Data And Split Integrity

Data checks:

- File existence, corrupt images/files, unsupported extensions, empty text, invalid rows.
- Label extraction on sampled raw items.
- Class/target distribution by split.
- Duplicate or near-duplicate inputs.
- Group leakage: patient, user, account, time period, source document, or scene.
- Train/valid/test transformation parity.

Split rules:

- Use `RandomSplitter(seed=...)` only when independent random splits are valid.
- Use `GrandparentSplitter`, `ColSplitter`, time-based splits, or custom splitters when deployment or leakage requires it.
- For medical, recommender, user, or time-series-adjacent data, assume random row/image splits are suspect until proven safe.

## Training Controls

Prefer simple, traceable training first:

```python
cbs = [
    SaveModelCallback(monitor="valid_loss", fname="best"),
    CSVLogger(fname="history.csv"),
]
learn.fine_tune(epochs, base_lr=lr, cbs=cbs)
```

Use:

- `learn.lr_find()` for LR exploration, then choose a defensible LR.
- `SaveModelCallback(with_opt=True, every_epoch=True, fname="ckpt")` or an integer `every_epoch` value for resumable periodic checkpoints.
- `EarlyStoppingCallback` only with a metric/patience that matches the problem.
- `learn.to_fp16()` or `learn.to_bf16()` after checking hardware support and numeric stability.
- `learn.distrib_ctx(...)` with Accelerate config for multi-GPU/distributed training.
- Experiment trackers when runs need auditability.

Avoid:

- Training longer before inspecting data and errors.
- Using validation loss alone when the deployment metric is asymmetric or imbalanced.
- Adding heavy augmentation, MixUp/CutMix, or a larger model without an ablation trail.

## Evaluation

Evaluation should answer deployment questions, not just notebook accuracy.

For classification:

- Confusion matrix, top losses, per-class precision/recall/F1, ROC-AUC or PR-AUC when useful.
- Threshold tuning for imbalanced or multi-label tasks.
- Calibration checks if scores drive decisions.

For regression:

- MAE/RMSE/R2, residual plots, error by segment, outlier behavior.

For segmentation:

- Dice/Jaccard by class, qualitative overlays, failure examples, small-object behavior.

For recommenders:

- Ranking metrics or business metrics when ratings loss is not the final objective.
- Cold-start behavior and unseen ID policy.

## Serialization And Serving

Options:

- `learn.save(...)` / `learn.load(...)`: training checkpoints and weights; safer than loading full pickle when only weights are needed.
- `learn.export("export.pkl")` / `load_learner(...)`: convenient full learner export for trusted environments.
- Raw PyTorch export/serving: use when deployment does not support fastai, but manually reproduce preprocessing and decoding.

Serving rules:

- Load the artifact once at process startup.
- Validate and normalize request inputs before prediction.
- Use `learn.predict(...)` for single items when fastai transforms and decoding are needed.
- Use `learn.get_preds(dl=...)` or a dedicated dataloader for batch inference.
- Return labels and scores with documented thresholding/calibration.
- Benchmark realistic batch sizes and worst-case inputs.

## Security

- `load_learner(...)` loads pickle data; never load untrusted or user-supplied learner files.
- Keep custom code used by exported learners in stable importable modules.
- Treat model artifacts as supply-chain artifacts: checksum, provenance, storage permissions, and review.
- Scrub secrets and private data from notebooks, exported artifacts, logs, and trackers.
- For medical or regulated data, add governance requirements outside fastai itself.

## Monitoring And Maintenance

Track:

- Input schema errors and preprocessing failures.
- Prediction distributions and confidence/score drift.
- Segment-level performance after labels arrive.
- Latency, memory, GPU utilization, and batch failure rates.
- Retraining data/version lineage.

For updates, compare against the incumbent model on the same held-out and production-like evaluation sets before replacing it.
