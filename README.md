# agent-skills

- `htmx`
- `fasthtml`
- `zig`
- `elixir`
- `fastai`
- `devenv`
- `dspy`
- `modern-python`
- `formal-modeling`

## Install for Pi

For Pi 1.0 and newer, install only Zig globally with the Skills CLI:

```bash
npx skills add h0rv/agent-skills --skill zig --agent pi --global --yes
```

Without `--global`, the skill is installed only for the current project.
Run `/reload` in an existing Pi session, then use `/skill:zig`.

To use the Zig skill directly from this checkout, run these commands from the repo root:

```bash
mkdir -p ~/.pi/agent/skills
ln -s "$PWD/zig" ~/.pi/agent/skills/zig
```

The link keeps the installed skill current as you edit this checkout.
If the destination already exists, inspect it before replacing it.

To install every skill as a native Pi package from this checkout:

```bash
pi install "$PWD"
```

The root `package.json` lists the skill directories for Pi. Without it,
native Pi package discovery expects a `skills/` directory, which this repo does not use.

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

## Checks

Run the manifest and local link checks with Node.js:

```bash
npm test
```

To also check every skill with a particular Pi version's parser, point
`PI_TEST_PACKAGE_DIR` at that installed or unpacked Pi package:

```bash
PI_TEST_PACKAGE_DIR=/path/to/pi-coding-agent npm test
```

The parser check is skipped when this variable is unset. It was checked with Pi 1.0.0 and 1.4.0.

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
ln -sfn "$PWD/formal-modeling" ~/.agents/skills/formal-modeling
```
