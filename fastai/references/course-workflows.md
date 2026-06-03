# Practical Deep Learning For Coders Workflows

Use this reference when the user is working through the course, reproducing lesson notebooks, adapting examples to personal data, or asking why fastai code works.

## Contents

- [Course-Oriented Response Style](#course-oriented-response-style)
- [Image Classification Recipe](#image-classification-recipe)
- [Multi-Label Classification Recipe](#multi-label-classification-recipe)
- [Segmentation Recipe](#segmentation-recipe)
- [Text Classification Recipe](#text-classification-recipe)
- [Tabular Recipe](#tabular-recipe)
- [Collaborative Filtering Recipe](#collaborative-filtering-recipe)
- [Improving Results](#improving-results)
- [From Course Notebook To Production](#from-course-notebook-to-production)
- [Deployment Notes](#deployment-notes)

## Course-Oriented Response Style

- Start from a working notebook cell or small patch, then explain the key concept.
- Preserve the user's experimentation loop: run, inspect, change one thing, compare.
- Connect fastai abstractions to concrete data flow: raw files/dataframe -> transforms -> batches -> model outputs -> loss/metrics.
- Prefer fixing the next failing cell over redesigning the entire notebook.
- When the user asks "why", explain both fastai's abstraction and the underlying PyTorch/deep-learning concept.

## Image Classification Recipe

Use high-level factories when possible:

```python
from fastai.vision.all import *

path = Path("data")
dls = ImageDataLoaders.from_folder(
    path,
    train="train",
    valid="valid",
    item_tfms=Resize(224),
    batch_tfms=aug_transforms(),
)

learn = vision_learner(dls, resnet34, metrics=error_rate)
learn.lr_find()
learn.fine_tune(3)
```

Switch to `DataBlock` when labels are in filenames, CSV rows, multiple columns, or a nonstandard split.

Debug checklist:

- Confirm image paths: `get_image_files(path)[:5]`.
- Confirm labels: call the `label_func` on a few filenames.
- Confirm classes: `dls.vocab`.
- Confirm batches: `dls.show_batch()`.
- For poor results, inspect top losses with `ClassificationInterpretation.from_learner(learn).plot_top_losses(...)`.

## Multi-Label Classification Recipe

Use `MultiCategoryBlock`, usually from a dataframe or CSV.

```python
dblock = DataBlock(
    blocks=(ImageBlock, MultiCategoryBlock),
    get_x=ColReader("fname", pref=path/"images"),
    get_y=ColReader("labels", label_delim=" "),
    splitter=RandomSplitter(seed=42),
    item_tfms=Resize(460),
    batch_tfms=aug_transforms(size=224),
)
```

Use threshold-aware metrics and verify the label delimiter before training.

## Segmentation Recipe

Use `SegmentationDataLoaders.from_label_func` for standard image/mask pairs, or `DataBlock` with `MaskBlock(codes)` for custom layouts.

```python
dls = SegmentationDataLoaders.from_label_func(
    path,
    bs=8,
    fnames=get_image_files(path/"images"),
    label_func=lambda o: path/"labels"/f"{o.stem}_P{o.suffix}",
    codes=np.loadtxt(path/"codes.txt", dtype=str),
)

learn = unet_learner(dls, resnet34)
learn.fine_tune(8)
```

Always verify mask filenames and class codes before training.

## Text Classification Recipe

Use folder or dataframe factories when data is conventional:

```python
from fastai.text.all import *

dls = TextDataLoaders.from_folder(path, valid="test")
learn = text_classifier_learner(dls, AWD_LSTM, drop_mult=0.5, metrics=accuracy)
learn.fine_tune(2, 1e-2)
```

For ULMFiT-style workflows, keep language-model and classifier vocab/tokenization aligned. If using `DataBlock`, make sure `TextBlock.from_df(...)` and classifier sequence length choices are consistent.

## Tabular Recipe

Use `TabularPandas` when preprocessing needs to be explicit:

```python
from fastai.tabular.all import *

procs = [Categorify, FillMissing, Normalize]
splits = RandomSplitter(seed=42)(range_of(df))
to = TabularPandas(
    df,
    procs=procs,
    cat_names=cat_names,
    cont_names=cont_names,
    y_names=y_name,
    y_block=CategoryBlock,
    splits=splits,
)
dls = to.dataloaders(bs=64)
learn = tabular_learner(dls, metrics=accuracy)
```

Check categorical/continuous columns and missing values before building `TabularPandas`.

## Collaborative Filtering Recipe

Use a ratings dataframe with user, item, and rating columns:

```python
from fastai.collab import *

dls = CollabDataLoaders.from_df(ratings, item_name="title", bs=64)
learn = collab_learner(dls, n_factors=50, y_range=(0, 5.5))
learn.fit_one_cycle(5, 5e-3)
```

Use `y_range` for bounded ratings. Keep stable IDs or titles for interpretation.

## Improving Results

Work in this order:

1. Verify the data and labels.
2. Inspect batches and predictions.
3. Use an appropriate metric and baseline.
4. Try LR changes using `lr_find`.
5. Train longer only after data and LR are plausible.
6. Try a stronger architecture, larger resize, augmentation changes, or cleaning mislabeled data.

Do not jump straight to more epochs or a bigger model when the data pipeline has not been inspected.

## From Course Notebook To Production

When a course notebook becomes a real model:

1. Freeze environment versions and record GPU/CPU details.
2. Replace ad hoc downloads and manual paths with deterministic data ingestion.
3. Make the validation split represent deployment, not notebook convenience.
4. Add dataset assertions: counts, missing files, corrupt files, label distribution, vocab, duplicates, leakage groups.
5. Replace course metrics with task metrics and business/domain acceptance criteria.
6. Save the best checkpoint with `SaveModelCallback`; save resumable checkpoints with optimizer state for long runs.
7. Keep the training notebook as an experiment, but move reusable data/model/inference code into importable modules before export.

## Deployment Notes

For course deployment:

- Export after training with `learn.export("export.pkl")`.
- Keep custom functions/classes in importable modules when possible.
- Load the learner once at app startup with `load_learner`.
- Do not load pickle files from untrusted sources.
- Convert uploaded files/text/rows into the same input type the learner saw during training.

Example inference shape:

```python
learn = load_learner("export.pkl")

def classify_image(img):
    label, idx, probs = learn.predict(img)
    return {str(label): float(probs[idx])}
```
