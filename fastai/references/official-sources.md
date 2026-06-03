# Official Sources

Use these sources before web answers, forum posts, or old notebooks.

## Latest Version Check

- PyPI package and release history: https://pypi.org/project/fastai/
- GitHub releases: https://github.com/fastai/fastai/releases
- GitHub source: https://github.com/fastai/fastai

As of 2026-06-03, PyPI lists fastai 2.8.7 as the latest release, released 2026-02-14, requiring Python >=3.10. GitHub marks v2.8.7 as latest and notes PyTorch <3 support. Re-check these pages before version-sensitive work.

## Primary

- Current documentation: https://docs.fast.ai/
- Quick start examples: https://docs.fast.ai/quick_start.html
- Tutorials index: https://docs.fast.ai/tutorial.html
- Practical Deep Learning for Coders: https://course.fast.ai/
- Course lesson notebooks and resources: open the relevant lesson page from https://course.fast.ai/Lessons/

## Core API Pages

- Data block API: https://docs.fast.ai/data.block.html
- Data block tutorial: https://docs.fast.ai/tutorial.datablock.html
- Data transforms: https://docs.fast.ai/data.transforms.html
- Data core/DataLoaders: https://docs.fast.ai/data.core.html
- DataLoaders internals: https://docs.fast.ai/data.load.html
- Learner, metrics, serialization: https://docs.fast.ai/learner.html
- Metrics: https://docs.fast.ai/metrics.html
- Interpretation: https://docs.fast.ai/interpret.html
- Optimizers: https://docs.fast.ai/optimizer.html
- Hyperparameter schedules, `fit_one_cycle`, `fine_tune`, `lr_find`: https://docs.fast.ai/callback.schedule.html
- Callback system: https://docs.fast.ai/callback.core.html
- Tracking callbacks: https://docs.fast.ai/callback.tracker.html
- Progress and logging callbacks: https://docs.fast.ai/callback.progress.html
- Mixed precision: https://docs.fast.ai/callback.fp16.html
- Distributed training: https://docs.fast.ai/distributed.html

## Domain Pages

- Vision tutorial: https://docs.fast.ai/tutorial.vision.html
- Vision learner: https://docs.fast.ai/vision.learner.html
- Vision data: https://docs.fast.ai/vision.data.html
- Vision augmentation: https://docs.fast.ai/vision.augment.html
- Text tutorial: https://docs.fast.ai/tutorial.text.html
- Text data: https://docs.fast.ai/text.data.html
- Text learner: https://docs.fast.ai/text.learner.html
- Tabular tutorial: https://docs.fast.ai/tutorial.tabular.html
- Tabular core: https://docs.fast.ai/tabular.core.html
- Tabular data: https://docs.fast.ai/tabular.data.html
- Tabular learner: https://docs.fast.ai/tabular.learner.html
- Collaborative filtering tutorial: https://docs.fast.ai/tutorial.collab.html
- Collaborative filtering API: https://docs.fast.ai/collab.html
- Medical imaging: https://docs.fast.ai/medical.imaging.html

## Integration Pages

- W&B: https://docs.fast.ai/callback.wandb.html
- TensorBoard: https://docs.fast.ai/callback.tensorboard.html
- Captum: https://docs.fast.ai/callback.captum.html
- Comet.ml: https://docs.fast.ai/callback.comet.html
- Hugging Face Hub: https://docs.fast.ai/huggingface.html

## Source Selection Rules

- Use docs pages for public signatures and normal usage.
- Use PyPI and GitHub releases for current released versions, Python requirements, and release-specific behavior.
- Use source links from docs pages or the GitHub repo for implementation-sensitive behavior.
- Use course pages for lesson order, notebooks, deployment context, and student-facing explanations.
- Use forums for troubleshooting only after checking current docs and version-specific behavior.
- Avoid `https://fastai1.fast.ai/` unless supporting a project pinned to fastai v1.
