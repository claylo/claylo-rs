---
status: "accepted"
date: 2026-01-05
decision-makers:
  - Clay Loveless
consulted: [ChatGPT]
informed: []
---
<!-- From https://github.com/adr/madr/blob/4.0.0/template/adr-template.md -->

# ADR-0009: Standardize log files with OpenTelemetry correlation

## Context and Problem Statement

We want application log output that is:

- **Immediately usable “out of the box”** by common log/monitoring stacks (initially **Datadog** and **AWS CloudWatch Logs Insights**).
- **Structured** (machine-parsable) while still being readable.
- **Vendor-neutral**, so switching backends does not require rewriting instrumentation.
- **Correlatable with traces**, so logs can jump to the trace/span that produced them.

Rust context:

- We already use or intend to use **`tracing`** as the primary instrumentation API.
- We want a “reasonable default” JSON log line format that works well for both:
  - log *files* (tail, filelog receiver, etc.), and
  - stdout/stderr capture (containers, Lambda, systemd/journald collectors).

### What “span” means in practice (why this matters)

A **span** is a single timed operation (a unit of work) inside a **trace**. Spans form a parent/child tree; the whole tree is “the request.” A **TraceId** groups all spans for a request, and each span has its own **SpanId**. This is what lets tools show “logs in context,” because a log line can carry the current `trace_id` and `span_id`. (See OpenTelemetry tracing concepts/spec for definitions.)

## Decision Drivers

- **Interoperability**: structured logs should import cleanly into Datadog and CloudWatch Logs Insights with minimal or no parsing configuration.
- **Correlation**: include `trace_id`/`span_id` so logs and traces can be linked.
- **Rust ergonomics**: keep developer experience simple; keep instrumentation idiomatic (`tracing` spans/events).
- **Operational simplicity**: prefer JSONL logs; file output should be the default with stdout fallback.
- **Schema stability**: keep a small set of “reserved” top-level keys and allow arbitrary event fields.

## Considered Options

### Option A — Plain text logs (human-only)

Examples: `println!`, logfmt, “pretty” tracing format.

- Good, because it’s human-friendly.
- Bad, because every downstream tool needs parsing rules; correlations and field queries are harder.

### Option B — `tracing_subscriber::fmt().json()` default JSON

- Good, because it is built-in and widely used.
- Bad, because the default structure nests fields (often under `fields`), which is less convenient for CloudWatch field discovery and for “drop-in” ingestion workflows.

### Option C — `json-subscriber` (structured JSON + OTel IDs)

- Good, because it can include OpenTelemetry IDs automatically.
- Bad/neutral, because the output shape is not as “flat” as desired by default (depending on configuration), and we want a log line that matches the common Datadog/collector examples as closely as possible.

### Option D — `tracing-ndjson` for flat JSONL output, plus OpenTelemetry for traces

- Good, because it produces a *flat* JSON object per line with configurable names for the core fields and supports common timestamp formats; span attributes and event fields are flattened into the root object.
- Neutral, because it currently logs to stdout only (file output is via redirection or collectors tailing stdout logs).
- Requires a small amount of instrumentation discipline to ensure events run inside spans so `trace_id`/`span_id` can be recorded.

### Option E — Adopt a strict cross-vendor log schema (ECS, etc.)

- Good, because it is a “known schema.”
- Bad, because it is heavier than needed for our current objective (Datadog + CloudWatch “just work”), and can force a lot of required fields that do not add value yet.

## Decision Outcome

We will standardize on:

1. **`tracing`** as the application instrumentation API (spans + events).
2. **JSONL / NDJSON** as the log transport format (one JSON object per line).
3. **Flat JSON log output** using a `tracing` layer that merges span + event fields.
4. **Daily-rotated log files** via **`tracing-appender`** (stdout fallback if file creation fails).
5. **OpenTelemetry tracing** via **`opentelemetry` + `tracing-opentelemetry`**, **opt-in** when `OTEL_EXPORTER_OTLP_ENDPOINT` or `otel_endpoint` config is set; we will **record `trace_id` and `span_id` into our spans** so they appear in every log line emitted within that span.

### Log event schema (baseline)

Each line is a single JSON object with (at minimum):

- `timestamp`: RFC3339Nano string
- `level`: `trace|debug|info|warn|error`
- `message`: string
- `target`: tracing target
- `service`: string (Datadog-friendly service name)
- `env`: string (Datadog-friendly environment)
- `version`: string (Datadog-friendly service version)
- `trace_id`: 32-hex trace id
- `span_id`: 16-hex span id
- plus any additional event fields (flattened)

This aligns with Datadog’s own “filelog + trace_parser” example JSON (same field names) and is also straightforward for CloudWatch Logs Insights field discovery/querying.

### Consequences

- ✅ Logs can be tailed/ingested as JSONL without custom grok rules.
- ✅ CloudWatch can auto-discover fields in a JSON log event; keep total fields under the documented limits.
- ✅ Datadog correlation works when `trace_id`/`span_id` are present and extracted (or directly ingested as attributes).
- ⚠️ We must ensure that important logs happen inside an active span (or we explicitly include correlation fields).
- ✅ Logs are written to a daily-rotated JSONL file by default.
- ⚠️ OTel export is opt-in; when disabled, `trace_id`/`span_id` fields are absent.

## Implementation (Rust)

The actual implementation uses a custom `JsonLogLayer` that:

1. Captures span fields when spans are created/updated
2. Propagates those fields into log events emitted within the span
3. Writes flat JSONL to daily-rotated files (with stderr fallback)

### Key Components

**`ObservabilityConfig`**: Holds service metadata and optional OTLP endpoint.

**`init_observability()`**: Sets up the tracing subscriber with:
- `EnvFilter` for log level control
- Optional `tracing-opentelemetry` layer (when OTLP endpoint is configured)
- Custom `JsonLogLayer` for JSONL file output

**`env_filter()`**: Builds an `EnvFilter` from CLI flags (`--quiet`/`--verbose`) or `RUST_LOG`.

### Current Behavior

- **Span field propagation**: Fields recorded on spans (e.g., `service`, `env`, `version`) are merged into log entries emitted within those spans.
- **OpenTelemetry tracing**: When `OTEL_EXPORTER_OTLP_ENDPOINT` is set, spans are exported via OTLP.
- **No automatic trace correlation in logs**: The current implementation does **not** automatically inject `trace_id`/`span_id` into log lines. This would require explicitly recording these fields using `tracing-opentelemetry`'s `OpenTelemetrySpanExt` trait.

### Adding Trace Correlation (Future Enhancement)

To add `trace_id`/`span_id` to logs, you would need to:

```rust
use tracing::{field, Span};
use tracing_opentelemetry::OpenTelemetrySpanExt;

// Create a span with empty correlation fields
let span = tracing::info_span!(
    "request",
    trace_id = field::Empty,
    span_id = field::Empty,
);

// Fill from OpenTelemetry context
let span_ctx = span.context().span().span_context().clone();
if span_ctx.is_valid() {
    span.record("trace_id", span_ctx.trace_id().to_string());
    span.record("span_id", span_ctx.span_id().to_string());
}
```

### Example Output

Without trace correlation:
```json
{"timestamp":"2026-01-05T22:17:14.841Z","level":"info","message":"User action","target":"my_crate","service":"my-service","user_id":123}
```

With trace correlation (if explicitly recorded):
```json
{"timestamp":"2026-01-05T22:17:14.841Z","level":"info","message":"User action","target":"my_crate","service":"my-service","trace_id":"e12c408e028299900d48a9dd29b0dc4c","span_id":"197492ff2b4e1c65","user_id":123}
```

See [Spec 0002](../specs/0002-otel-ndjson-logging/README.md) for configuration details.

## Operational notes (Datadog + CloudWatch)

### Datadog

Datadog’s OpenTelemetry collector guidance shows JSON logs containing `service`, `timestamp`, `level`, `message`, `trace_id`, and `span_id`, and uses a `trace_parser` operator to extract IDs for correlation. If you ingest logs directly, keep these keys at the top level.

### CloudWatch Logs Insights

- CloudWatch can automatically discover fields in JSON logs, but (notably for Lambda logs) discovery is only for the **first embedded JSON fragment** in each log event.
- JSON logs are flattened during ingestion, and CloudWatch Logs Insights can extract up to **200** fields from a JSON log event.

This is why we want a single JSON object per log line and to keep the baseline field set small.

