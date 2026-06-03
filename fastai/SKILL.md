---
name: fastai
description: Build, debug, explain, review, and productionize fastai deep learning workflows using current fastai v2 docs and source. Use when working with Practical Deep Learning for Coders notebooks, `fastai.*.all` imports, installation/version checks, `DataBlock`, `Datasets`, `DataLoaders`, `Transform`, `Learner`, `vision_learner`, `cnn_learner`, `unet_learner`, `language_model_learner`, `text_classifier_learner`, `tabular_learner`, `collab_learner`, medical imaging helpers, transfer learning, LR finder, callbacks, metrics, interpretation, mixed precision, distributed training, export/load_learner, or fastai/PyTorch/timm/Accelerate interop.
---

# fastai

Use current fastai v2 patterns from `docs.fast.ai`, PyPI, and the `fastai/fastai` repo. As of 2026-06-03, PyPI's latest release is fastai 2.8.7, released 2026-02-14, requiring Python >=3.10. Verify PyPI/GitHub again before making version-sensitive recommendations.

## Start Here

1. Inspect the local project first: imports, installed `fastai` version, notebook style, data layout, and whether the user is following a course notebook.
2. Prefer application-level fastai APIs for course, baseline, and standard domain work; drop to `DataBlock`, mid-level transforms, `Learner`, callbacks, optimizers, or raw PyTorch only when the task needs that control.
3. In notebooks, follow fastai's domain import style such as `from fastai.vision.all import *`, `from fastai.text.all import *`, `from fastai.tabular.all import *`, or `from fastai.collab import *`. In production/package code, prefer explicit imports if the repo already avoids wildcard imports.
4. Build the workflow around the fastai loop: create `DataLoaders`, inspect a batch, create a `Learner`, find or choose an LR, train/fine-tune, inspect results, then save/export.
5. For production models, require reproducible splits, version pins, dataset checks, appropriate metrics, callback-based checkpointing, a documented inference path, and a security stance for serialized artifacts.
6. When answering Practical Deep Learning for Coders questions, connect the code to the course concepts without replacing the user's experimentation loop.

## Default Workflow

Use this shape for most training tasks:

```python
from fastai.vision.all import *

path = untar_data(URLs.PETS) / "images"
dls = ImageDataLoaders.from_name_func(
    path, get_image_files(path), valid_pct=0.2, seed=42,
    label_func=lambda x: x[0].isupper(),
    item_tfms=Resize(224),
)

dls.show_batch(max_n=9)

learn = vision_learner(dls, resnet34, metrics=error_rate)
learn.fine_tune(1)
learn.show_results()
```

Adapt the import, dataloader factory, model factory, metric, and target extraction to the domain. For custom data layouts, use `DataBlock` instead of forcing a high-level factory.

Read [api-levels.md](references/api-levels.md) when choosing between high-level factories, `DataBlock`, mid-level transforms, `Learner`, callbacks, optimizers, metrics, distributed/mixed precision, or raw PyTorch interop.

Read [domain-apis.md](references/domain-apis.md) when the task depends on a domain surface: vision, segmentation, text/language modeling, tabular, collaborative filtering, medical imaging, or integrations.

## Data Rules

- Always make the split explicit enough to be reproducible: `RandomSplitter(seed=...)`, `GrandparentSplitter`, `ColSplitter`, or a project-specific splitter.
- Inspect data before training with `dls.show_batch()`, `DataBlock.summary(...)`, dataframe checks, `dls.one_batch()`, and label/vocab sanity checks.
- Put item shape normalization in `item_tfms` and randomized batch augmentation in `batch_tfms`.
- Keep target extraction small and testable: `parent_label`, `RegexLabeller`, `ColReader`, `using_attr`, or a named function when logic is non-trivial.
- Match blocks, loss, output shape, and metrics to the target: `CategoryBlock` for single label, `MultiCategoryBlock` for multi-label, `RegressionBlock` for continuous targets, `MaskBlock`/segmentation loaders for masks.

## Training Rules

- Use `vision_learner`, `unet_learner`, `language_model_learner`, `text_classifier_learner`, `tabular_learner`, or `collab_learner` when the domain fits.
- Treat `cnn_learner` as a deprecated alias for `vision_learner`: preserve it in existing code if churn is not useful, but do not introduce it in new examples.
- Use `learn.lr_find()` to choose a learning rate when training is unstable, slow, or user asks how to improve results. Treat suggestions as starting points, not guarantees.
- Use `learn.fine_tune(...)` for pretrained transfer learning. Use `learn.fit_one_cycle(...)` for training from scratch or after custom freezing/unfreezing decisions.
- Prefer metrics that match the real task: `accuracy`/`error_rate` for balanced classification, `BalancedAccuracy`/F1/ROC-AUC for imbalanced classification, threshold-aware `*Multi` metrics for multi-label work, RMSE/MAE/R2 for regression, Dice/Jaccard for segmentation.
- Use `SaveModelCallback`, `EarlyStoppingCallback`, logging/tracking callbacks, mixed precision, and distributed training deliberately; do not add them as decoration.
- For PyTorch interop, create fastai `DataLoaders` when possible. If using plain PyTorch dataloaders, call out which fastai display and interpretation features may be unavailable.

## Inference And Deployment

- Use `learn.predict(item)` for single-item inference and `learn.get_preds(...)` for batch predictions.
- Use `learn.export("export.pkl")` only for trusted deployment artifacts. Custom functions/classes used by transforms, models, losses, or metrics must be importable in the deployment environment.
- Warn that `load_learner(...)` uses pickle semantics and must not load untrusted files. Use `Learner.load(...)` for weights/checkpoints when a full exported learner is not needed.
- Keep the inference path faithful to training transforms. Do not replace `learn.predict(...)` with direct `learn.model(...)` unless preprocessing, decoding, activation, and device handling are explicitly reproduced.
- For service deployment, load the learner/model once at startup, validate inputs, bound batch size and image/text lengths, return calibrated or clearly documented scores, and monitor drift and failures.

Read [course-workflows.md](references/course-workflows.md) for Practical Deep Learning for Coders-oriented recipes, study workflow, common domain templates, and deployment notes.

Read [production-models.md](references/production-models.md) when building, reviewing, deploying, or improving a model intended to run beyond a notebook.

## Source Selection

- Prefer `https://docs.fast.ai/` for current API behavior.
- Prefer PyPI and GitHub releases for latest released version, Python requirement, and release notes.
- Prefer `https://github.com/fastai/fastai` source when behavior depends on implementation details, signatures, version differences, or docs ambiguity.
- Prefer `https://course.fast.ai/` and the fastai book/course notebooks when the user asks in a Practical Deep Learning for Coders context.
- Avoid copying old answers from forums or Stack Overflow without checking against current docs.

Open [official-sources.md](references/official-sources.md) for the exact docs, repo, course, and source links to consult.
