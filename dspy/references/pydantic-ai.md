# Optimizing Pydantic AI agents (without porting to DSPy)

You do not need to rewrite an agent as a DSPy program to optimize it. The DSPy optimization method (especially GEPA) is available as a standalone `gepa` package, and Pydantic AI exposes the hooks to drive it. As of 2026-06 the Pydantic team has stated they will not add specific optimizers to the core package; instead they ship generic extensibility (agent specs and capabilities) so optimization can be built as composable, reusable units. Verify current API against `https://ai.pydantic.dev`.

## The two primitives that make this work

### AgentSpec

An `AgentSpec` is a declarative configuration object for an agent: model, instructions (with optional template variables), capabilities, model settings (such as `max_tokens`, temperature), output schema, dependencies schema, retry configuration, and metadata. Specs load from YAML or JSON:

```python
agent = Agent.from_file("agent.yaml")     # or Agent.from_spec(spec)
```

```yaml
# agent.yaml
model: anthropic:claude-haiku-4-5
instructions: "Extract the invoice fields. {{format_hints}}"
model_settings:
  max_tokens: 4000
```

Candidate specs are injected into an existing agent at evaluation time with the override context manager, which swaps configuration thread-safely (via context variables) without mutating the agent definition:

```python
with agent.override(spec=candidate_spec):
    result = await agent.run(user_input, deps=deps)
```

This is the key difference from DSPy. DSPy's optimizers rewrite the signature docstring only. An `AgentSpec` carries instructions plus capabilities plus model settings plus model choice, so an optimizer driving `override(spec=...)` can co-optimize all of them in one search, not just the prompt text.

### Capabilities

A capability is a reusable, composable unit of agent behavior: it can contribute tools (toolsets or native tools), instructions (static or dynamic), model settings (static or per-step), and lifecycle hooks that intercept and modify model requests, tool calls, and the run. Capabilities compose by stacking:

```python
from pydantic_ai import Agent
from pydantic_ai.capabilities import Thinking, WebSearch

agent = Agent(
    "anthropic:claude-opus-4-6",
    instructions="You are a research assistant.",
    capabilities=[Thinking(effort="high"), WebSearch(local="duckduckgo")],
)
```

Define a custom one by subclassing `AbstractCapability` and overriding the methods you need (`get_instructions`, `get_toolset`, `get_model_settings`, `get_native_tools`) plus lifecycle hooks (`before_run`, `after_run`, `wrap_run`, `before_model_request`, `before_tool_execute`, and their variants). This is the blessed packaging path for an optimizer: ship the optimization loop as a capability so it is reusable across agents instead of bespoke glue.

## The optimization loop

Combine standalone `gepa`, the override hook, and Pydantic Evals as the metric harness:

1. **Evaluate**: run the current candidate spec on a minibatch via a Pydantic Evals `Dataset.evaluate(task)`, which gives parallel per-case scores and OpenTelemetry traces. Inject the candidate with `agent.override(spec=candidate)`.
2. **Reflect**: build a dataset of failures with natural-language feedback from the eval report (which fields were wrong and why).
3. **Propose**: a proposer LLM rewrites the spec (instructions, and optionally capabilities/settings) from the failures.
4. **Accept/Reject**: keep the mutation only if it wins on a validation subsample.

```python
with agent.override(spec=candidate):
    report = await dataset.evaluate(task, max_concurrency=n)
# pull accuracy via score_key, build trajectories from report cases for reflection
```

Required packages: `pydantic-ai`, `pydantic-evals`, `gepa` (plus a provider SDK).

## Existing third-party work

These projects implement optimizers against Pydantic AI and are candidates to use or borrow from; the maintainers have encouraged them to publish as Capabilities:

- `https://github.com/svilupp/pydantic-ai-optimizers`
- `https://github.com/mwildehahn/pydantic-ai-gepa`
- `https://github.com/davidberenstein1957/dspydantic` (optimizes Pydantic model field descriptions for extraction)

Reference article: `https://pydantic.dev/articles/prompt-optimization-with-gepa`.

## Limitations to state plainly

- Single-module optimization loses GEPA's crossover benefit (crossover needs multiple prompts/modules).
- Quality is bounded by the eval: GEPA can only optimize what you can measure.
- Cost-intensive: a modest run (for example 50 iterations over 8 cases) is hundreds of LLM calls.
- No regression guarantee beyond the acceptance test, so keep a held-out test set and confirm the final spec there.

## When to use this vs DSPy proper

Use this path when the agent already lives in Pydantic AI and you want to optimize it in place, especially when the search should include capabilities or model settings, not just instructions. Use DSPy proper when you want multi-module joint optimization, the richer set of optimizer implementations, or a program authored declaratively from the start.
