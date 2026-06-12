# fastai API Levels

Use this reference when deciding how high or low in the fastai stack to work.

## Contents

- [Version Baseline](#version-baseline)
- [Layer 1: Application Factories](#layer-1-application-factories)
- [Layer 2: DataBlock](#layer-2-datablock)
- [Layer 3: Datasets, DataLoaders, And Transforms](#layer-3-datasets-dataloaders-and-transforms)
- [Layer 4: Learner](#layer-4-learner)
- [Layer 5: Training System](#layer-5-training-system)
- [Layer 6: PyTorch Interop](#layer-6-pytorch-interop)
- [Version And Naming Notes](#version-and-naming-notes)

## Version Baseline

As of 2026-06-03, latest released fastai is 2.8.7 on PyPI, released 2026-02-14. PyPI lists Python >=3.10. GitHub release notes for v2.8.7 allow PyTorch \<3. Verify both before making a version-sensitive claim.

Use:

```bash
python -c "import fastai, torch; print(fastai.__version__, torch.__version__)"
python -m pip show fastai torch torchvision fastcore fasttransform
```

Install PyTorch for the target CUDA/CPU platform before or alongside fastai. For local production work, pin `fastai`, `torch`, `torchvision`, `fastcore`, `fasttransform`, Python, CUDA, and platform/container image.

## Layer 1: Application Factories

Use first for ordinary projects, Practical Deep Learning for Coders notebooks, and production baselines.

Common data factories:

- Vision classification: `ImageDataLoaders.from_folder`, `.from_name_func`, `.from_name_re`, `.from_path_func`, `.from_df`
- Segmentation: `SegmentationDataLoaders.from_label_func`
- Text: `TextDataLoaders.from_folder`, `.from_df`
- Tabular: `TabularDataLoaders.from_df` or `TabularPandas(...).dataloaders()`
- Collaborative filtering: `CollabDataLoaders.from_df`

Common learner factories:

- Vision classification/regression: `vision_learner(dls, arch, metrics=...)`
- Segmentation: `unet_learner(dls, arch, metrics=...)`
- Language modeling: `language_model_learner(dls, AWD_LSTM, metrics=...)`
- Text classification: `text_classifier_learner(dls, AWD_LSTM, metrics=...)`
- Tabular: `tabular_learner(dls, metrics=...)`
- Collaborative filtering: `collab_learner(dls, n_factors=..., y_range=...)`

Prefer these APIs when the data follows a conventional layout and the user needs speed, clarity, or course alignment.

Application factories are still appropriate in production when the pipeline is conventional and covered by tests. Do not rewrite a factory into lower-level code only for sophistication.

## Layer 2: DataBlock

Use `DataBlock` when data layout, labeling, splitting, inputs, or targets are custom.

Answer these questions before writing the block:

- What are the input and target types? Set `blocks=(...)`.
- Where are the raw items? Set `get_items`.
- How are items split into train/validation? Set `splitter`.
- How is `x` derived? Set `get_x` when the raw item is not already the input.
- How is `y` derived? Set `get_y`.
- What runs per item? Set `item_tfms`.
- What runs per batch? Set `batch_tfms`.

Minimal image example:

```python
pets = DataBlock(
    blocks=(ImageBlock, CategoryBlock),
    get_items=get_image_files,
    splitter=RandomSplitter(seed=42),
    get_y=using_attr(RegexLabeller(r"(.+)_\d+.jpg$"), "name"),
    item_tfms=Resize(460),
    batch_tfms=aug_transforms(size=224),
)

dls = pets.dataloaders(path)
pets.summary(path)
```

Use `DataBlock.summary(source)` when the pipeline fails or labels/transforms look wrong.

DataBlock facts to preserve:

- `blocks` declare semantic input/target types and attach default type/item/batch transforms.
- `n_inp` matters for multi-input or multi-target tasks.
- `getters` is the escape hatch when `get_x`/`get_y` are not enough.
- `summary(source, bs=..., show_batch=True)` walks one batch through the pipeline and is the fastest way to debug transform order.

## Layer 3: Datasets, DataLoaders, And Transforms

Use this level when `DataBlock` is not expressive enough, or when debugging custom transforms.

Relevant concepts:

- `Transform`, `Pipeline`, and fasttransform-based dispatch compose typed transformations.
- `Datasets` applies item transforms and stores train/validation splits.
- `TfmdDL` and `DataLoaders` handle batching and batch transforms.
- `show_batch` and `show_results` depend on fastai's type and display dispatch.

Rules:

- Put deterministic decoding/type conversion in type transforms.
- Put per-item resize/cropping/tokenization setup in `item_tfms`.
- Put GPU-friendly tensor conversion, normalization, augmentation, and batch transforms in `batch_tfms`.
- Keep custom transforms small. Prefer named functions/classes over inline lambdas when code must be exported, reused, or loaded through pickle.
- If a custom type cannot display, implement or reuse `show_batch`/`show_results` behavior before assuming training is broken.

## Layer 4: Learner

Use `Learner` directly when the model, loss, optimizer, splitter, callbacks, or metrics do not fit an application factory.

Minimal shape:

```python
learn = Learner(
    dls,
    model,
    loss_func=loss_func,
    opt_func=Adam,
    metrics=metrics,
)
```

Key constructor decisions:

- `loss_func`: must match model output and target encoding.
- `opt_func`: default `Adam` is fine for many tasks; use `Adam`, `AdamW`, `SGD`, or custom fastai optimizer wrappers deliberately.
- `splitter`: required for meaningful freezing/discriminative LRs on custom models.
- `cbs`: add callbacks for checkpointing, logging, mixed precision, data tricks, or custom behavior.
- `metrics`: validation-time reporting only; do not use metrics as losses unless they are differentiable and intended for that.

## Layer 5: Training System

Training methods:

- `learn.fit(n_epoch, lr=...)`: basic training loop.
- `learn.fit_one_cycle(n_epoch, lr_max=...)`: one-cycle schedule for from-scratch training.
- `learn.fine_tune(epochs, base_lr=..., freeze_epochs=...)`: transfer learning pattern that trains a head while frozen, then unfreezes and trains with discriminative learning rates.
- `learn.lr_find()`: short exploratory run that suggests useful LR ranges.

Common production-useful callbacks and APIs:

- `SaveModelCallback(monitor=..., fname=..., with_opt=True)`: checkpoint best models; add `every_epoch=True` or an integer when resumable periodic checkpoints are needed.
- `EarlyStoppingCallback(monitor=..., patience=...)`: stop when validation stops improving; pair with checkpointing.
- `CSVLogger`, TensorBoard, W&B, Comet, and related callbacks: record runs and artifacts.
- `learn.to_fp16()`, `learn.to_bf16()`, `learn.to_fp32()`: mixed precision via PyTorch AMP.
- `learn.distrib_ctx(...)`: distributed training through Accelerate when configured.
- `MixUp`, `CutMix`, label smoothing, and other training callbacks: add only when task and metric support them.

Metrics and interpretation:

- Use `accuracy`/`error_rate` only when classes are balanced enough and top-1 classification is the objective.
- Use `BalancedAccuracy`, F1/FBeta, ROC-AUC, precision/recall, or confusion matrices for imbalanced classification.
- Use `accuracy_multi`, `F1ScoreMulti`, `JaccardMulti`, `RocAucMulti`, or tuned thresholds for multi-label tasks.
- Use `rmse`, `mae`, `mse`, `R2Score`, or domain loss/metrics for regression.
- Use Dice/Jaccard metrics for segmentation.
- Use `ClassificationInterpretation`, confusion matrices, top losses, and per-slice/domain error analysis before changing architecture.

## Layer 6: PyTorch Interop

Use raw PyTorch when the project already has custom models/dataloaders or needs behavior fastai does not model.

Rules:

- A fastai `Learner` can wrap a standard PyTorch `nn.Module`.
- The model output shape must match the target shape and loss function.
- Plain PyTorch dataloaders can be wrapped in fastai `DataLoaders`, but display, decoding, and interpretation helpers may be weaker.
- If using a PyTorch optimizer, wrap it in a fastai-compatible optimizer function when schedulers, freezing, or discriminative learning rates are needed.
- For inference outside fastai, reproduce preprocessing, device placement, activation/decoding, vocab mapping, and thresholding explicitly.

## Version And Naming Notes

- Prefer `vision_learner` in new examples because it is the primary current docs path, but do not rewrite valid existing `cnn_learner` code just for naming.
- Current docs mark `cnn_learner` as a deprecated name for `vision_learner`; do not introduce it in new code.
- Treat `fastai1.fast.ai` examples as old-style unless the local project is pinned to fastai v1.
- Check the installed package version when a method seems missing.
