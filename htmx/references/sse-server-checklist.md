# SSE Server Checklist

## Contents

- Required response behavior
- Minimal event format
- Operational checks
- Failure modes
- Primary sources

## Required response behavior

An SSE endpoint is a long-lived HTTP response, not a normal JSON route.

Verify these basics:

- Set `Content-Type: text/event-stream`
- Set cache behavior so intermediaries do not cache the stream
- Disable proxy or server buffering where required by the stack
- Keep the connection open and write events over time
- Flush after writes when the runtime requires it
- Stop the loop when the client disconnects

## Minimal event format

SSE is line-oriented text. Each event ends with a blank line.

Named event:

```text
event: status
data: <div>Running</div>

```

Unnamed event:

```text
data: <div>Running</div>

```

Use `event:` when the client listens with `sse-swap="status"` or `hx-trigger="sse:status"`.

## Operational checks

Before calling an SSE implementation done, confirm:

- The browser receives a streaming response, not one buffered chunk at the end
- The page updates after each event, not only after request completion
- Reconnect behavior is acceptable when the connection drops
- The stream is coarse-grained enough that you are not opening one connection per small widget
- Heartbeats or comment lines are present if your infra times out quiet streams

## Failure modes

Common mistakes:

- Returning JSON with `application/json`
- Writing valid SSE lines but forgetting the blank line between events
- Sending events without flushing in runtimes that buffer writes
- Putting load-balanced or reverse-proxy buffering in front of the stream
- Using SSE as a write channel or as a timer that just causes more HTTP fetches

If the delivery path is unreliable or heavily buffered, choose polling first and keep the system simple.

## Primary sources

- HTMX SSE extension docs: https://htmx.org/extensions/sse/
- MDN Using server-sent events: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events
- MDN EventSource: https://developer.mozilla.org/en-US/docs/Web/API/EventSource
