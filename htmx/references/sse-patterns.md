# SSE Patterns

## Contents

- Choose SSE for push
- Use the htmx SSE extension
- Pick the right event shape
- Prefer direct swaps over orchestration
- Server checklist
- Review anti-patterns
- Primary sources

## Choose SSE for push

Use SSE when the server already knows that something changed and the browser should be updated without polling.

Good fits:

- Job progress
- Build logs
- Notifications
- Queue status
- Live audit trails
- Dashboard cards that change when back-end events happen

Do not use SSE when:

- The browser needs to send data to the server after the stream starts
- The UI is really just a periodic refresh
- The client is using events as commands to immediately fetch everything again

If the browser should ask on a schedule, use `hx-trigger="every Ns"`. If both sides need to speak over the same long-lived channel, use WebSockets.

## Use the htmx SSE extension

Put the extension and connection on an owning container:

```html
<section hx-ext="sse" sse-connect="/jobs/abc/stream">
  <div id="job-status" sse-swap="status"></div>
  <pre id="job-log" sse-swap="log"></pre>
</section>
```

Use named events that line up with stable UI regions.

When the SSE payload is already the HTML fragment you want, prefer `sse-swap`. It keeps the behavior direct and local.

Use `hx-trigger="sse:event-name"` with `hx-get` only when the event should cause a follow-up request for a broader or shared render:

```html
<section hx-ext="sse" sse-connect="/inbox/stream">
  <div
    hx-get="/inbox/panel"
    hx-trigger="sse:inbox-updated"
    hx-target="#inbox-panel">
  </div>
</section>
```

This pattern is acceptable when the server wants to send a small signal and reuse an existing HTTP render path. Do not turn it into an event-driven polling loop.

## Pick the right event shape

Prefer a small set of named events with obvious ownership:

- `status`
- `log`
- `notification`
- `job-finished`

Avoid many ultra-granular event names that force the client to coordinate too much state.

Keep connections coarse-grained. One stream per page or logical region is usually enough.

Use `sse-close` when a stream should end cleanly:

```html
<section
  hx-ext="sse"
  sse-connect="/jobs/abc/stream"
  sse-close="job-finished">
  <div sse-swap="status"></div>
</section>
```

## Prefer direct swaps over orchestration

Best:

- Server sends `event: status` with HTML for the status panel
- Client swaps that HTML into the matching region

Acceptable:

- Server sends `event: inbox-updated`
- Client performs one follow-up `hx-get` for a shared panel render

Usually wrong:

- Server emits frequent events solely to tell the browser to poll another endpoint
- Client opens many parallel streams for small fragments
- Client uses SSE for writes, commands, or request-response flows

## Server checklist

Before shipping SSE, verify the endpoint itself is correct:

- Respond with `Content-Type: text/event-stream`
- Disable buffering where your stack or proxy requires it
- Disable caching for the stream
- Send events in SSE wire format with fields like `event:` and `data:`
- End each event block with a blank line
- Flush after each event when your runtime requires explicit flushing
- Stop work when the client disconnects
- Send periodic comments or heartbeat events when the infrastructure needs keep-alives

Minimal event shape:

```text
event: status
data: <div>Running</div>

```

If the endpoint cannot satisfy these basics, do not pretend it is SSE. Use polling until the server path is correct.

## Review anti-patterns

Push back on these patterns:

- "Use SSE every few seconds to refresh the page"
- "Emit an SSE event after each timer tick so the client can `hx-get` again"
- "Use SSE to submit a form result"
- "Open one EventSource per widget by default"
- "Mirror server state in client stores just to apply SSE updates"

The simplest mental model is: user actions go up with HTTP requests; unsolicited server facts come down with SSE.

## Primary sources

- HTMX SSE extension docs: https://htmx.org/extensions/sse/
- EventSource overview: https://developer.mozilla.org/en-US/docs/Web/API/EventSource
- Using server-sent events: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events
