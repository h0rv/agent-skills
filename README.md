# agent-skills

- `htmx`
- `fasthtml`
- `zig`
- `elixir`
- `fastai`
- `devenv`
- `dspy`
- `modern-python`

## Install with Vercel skills

List available skills:

```bash
npx skills add h0rv/agent-skills --list
```

Install one skill:

```bash
npx skills add h0rv/agent-skills --skill fastai
```

Install every skill in this repo:

```bash
npx skills add h0rv/agent-skills --all
```

## Manual symlinks

```bash
mkdir -p ~/.agents/skills
ln -sfn "$PWD/htmx" ~/.agents/skills/htmx
ln -sfn "$PWD/fasthtml" ~/.agents/skills/fasthtml
ln -sfn "$PWD/zig" ~/.agents/skills/zig
ln -sfn "$PWD/elixir" ~/.agents/skills/elixir
ln -sfn "$PWD/fastai" ~/.agents/skills/fastai
ln -sfn "$PWD/devenv" ~/.agents/skills/devenv
ln -sfn "$PWD/dspy" ~/.agents/skills/dspy
ln -sfn "$PWD/modern-python" ~/.agents/skills/modern-python
```
