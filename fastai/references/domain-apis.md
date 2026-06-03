# Domain APIs

Use this reference when the task depends on a specific fastai domain surface.

## Contents

- [Vision Classification And Regression](#vision-classification-and-regression)
- [Segmentation](#segmentation)
- [Text And Language Modeling](#text-and-language-modeling)
- [Tabular](#tabular)
- [Collaborative Filtering](#collaborative-filtering)
- [Medical Imaging And Medical Text](#medical-imaging-and-medical-text)
- [Integrations](#integrations)
- [Common Import Policy](#common-import-policy)

## Vision Classification And Regression

Primary imports:

```python
from fastai.vision.all import *
```

Core APIs:

- Data: `get_image_files`, `ImageDataLoaders.from_folder`, `.from_path_func`, `.from_path_re`, `.from_name_func`, `.from_name_re`, `.from_df`, `.from_csv`, `.from_lists`
- Blocks: `ImageBlock`, `CategoryBlock`, `MultiCategoryBlock`, `RegressionBlock`
- Transforms: `Resize`, `RandomResizedCrop`, `aug_transforms`, `Normalize`, `PILImage`, `PILImageBW`
- Learner: `vision_learner`
- Models: `models.resnet*`, xresnet models, torchvision models, timm architectures where supported
- Interpretation: `ClassificationInterpretation.from_learner(learn)`, `plot_confusion_matrix`, `plot_top_losses`

Rules:

- Use `vision_learner`, not `cnn_learner`, in new code.
- Use `weights=...` for TorchVision multi-weight API when exact pretrained weights matter.
- For non-RGB inputs, set `n_in` or use the right image class/block and verify model first-layer behavior.
- For regression, pass a regression-compatible target block, output shape, loss, and metrics.
- Inspect class imbalance and label noise before increasing epochs.

## Segmentation

Primary APIs:

- Data: `SegmentationDataLoaders.from_label_func`
- Blocks: `ImageBlock`, `MaskBlock(codes)`
- Learner: `unet_learner`
- Metrics/losses: Dice, Jaccard, foreground accuracy, `CrossEntropyLossFlat(axis=1)` when appropriate

Rules:

- Validate mask filename mapping on sample files before creating dataloaders.
- Confirm `codes` order matches mask pixel values.
- Use `dls.show_batch()` and `learn.show_results()` early; visual mismatches are common.
- Keep image and mask transforms synchronized through fastai's typed transform system.

## Text And Language Modeling

Primary import:

```python
from fastai.text.all import *
```

Core APIs:

- Data: `TextDataLoaders.from_folder`, `.from_df`, `.from_csv`
- Blocks: `TextBlock`, category/multi-category blocks as targets
- Language model: `language_model_learner(dls, AWD_LSTM, ...)`
- Classifier: `text_classifier_learner(dls, AWD_LSTM, ...)`
- Transfer: `TextLearner.save_encoder(...)`, `TextLearner.load_encoder(...)`
- Generation: language-model `learn.predict(text, n_words=...)`

Rules:

- Use `is_lm=True` when creating language-model dataloaders.
- Keep tokenizer, vocabulary, sequence length, and pretrained encoder assumptions aligned between language model and classifier.
- For classification, verify `text_col`, `label_col`, `valid_col`, and `label_delim`.
- Long text inference can be bounded by `seq_len`/`max_len` behavior; test realistic lengths.

## Tabular

Primary import:

```python
from fastai.tabular.all import *
```

Core APIs:

- Data: `TabularPandas`, `TabularDataLoaders.from_df`
- Preprocessing: `Categorify`, `FillMissing`, `Normalize`
- Learner: `tabular_learner`
- Prediction: `learn.predict(row)` with a dataframe row or compatible row object

Rules:

- Define `cat_names`, `cont_names`, `y_names`, and `y_block` explicitly for production.
- Fit preprocessing on the training split only through `TabularPandas(..., splits=...)`.
- Preserve category vocabularies and continuous normalization from training for inference.
- Use time-aware or group-aware splits when rows are not independent and identically distributed.

## Collaborative Filtering

Primary import:

```python
from fastai.collab import *
```

Core APIs:

- Data: `CollabDataLoaders.from_df`
- Learner: `collab_learner`
- Models: embedding dot-bias model by default; neural-net option with `use_nn=True`

Rules:

- Set `user_name`, `item_name`, and rating column arguments when the dataframe is not in the expected order.
- Use `y_range` for bounded ratings.
- Plan for cold-start users/items; fastai embeddings only learn seen IDs.
- Keep ID mapping stable between training and serving.

## Medical Imaging And Medical Text

Use only when the domain really is medical and the project has appropriate data governance.

Medical imaging APIs include:

- `fastai.medical.imaging`
- `get_dicom_files`
- `Path.dcmread`
- `TensorDicom`, `PILDicom`, `TensorCTScan`, `PILCTScan`
- DICOM pixel helpers: `scaled_px`, `hist_scaled`, `windowed`, `dicom_windows`
- `DicomSegmentationDataLoaders`

Rules:

- Verify PHI handling, modality assumptions, pixel scaling, orientation, windowing, and train/validation grouping by patient/study.
- Do not use random image-level splits when slices from the same patient can leak across splits.
- Use domain metrics and clinical validation expectations, not only generic accuracy.

## Integrations

Fastai documents integrations for W&B, TensorBoard, Comet.ml, Captum, and Hugging Face Hub.

Use integrations when they solve a concrete production need:

- Run tracking and artifact lineage: W&B, TensorBoard, CSVLogger, Comet.
- Explainability: Captum, interpretation helpers, domain-specific audit reports.
- Model sharing: Hugging Face Hub only when packaging, licensing, and security posture are clear.
- Distributed training: Accelerate through `learn.distrib_ctx(...)` and the documented launch/config flow.

## Common Import Policy

- In notebooks and course work, use domain `all` imports for speed and alignment with docs.
- In production modules, follow the repo style; prefer explicit imports if existing code is explicit.
- Avoid mixing old fastai v1 imports or `fastai.vision` v1 examples with current fastai v2 APIs.
