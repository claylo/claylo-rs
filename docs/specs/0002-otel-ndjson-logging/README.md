# 0002. OTel + NDJSON Logging

- Date: 2026-01-06
- Status: :white_check_mark: Active
- ADRs: ../../decisions/0009-standardize-logs-files-with-opentelemetry-correlation.md#decision-outcome
- Related: None

## Goal

Emit flat JSONL logs to a daily-rotated file with optional OpenTelemetry
tracing and a small set of top-level fields that work with Datadog and
CloudWatch Logs Insights.

## Scope

- Initialize OpenTelemetry tracing with OTLP exporter when opt-in is enabled.
- Emit JSONL logs to a rolling file (daily rotation).
- Propagate span fields into log entries.
- Keep logging configuration driven by CLI flags and `RUST_LOG`.

> **Note**: The current implementation does **not** automatically inject
> `trace_id`/`span_id` into log lines. To add trace correlation, you would need
> to explicitly record these fields on spans using `tracing-opentelemetry`'s
> `OpenTelemetrySpanExt` trait. See ADR-0009 for the design rationale.

## Implementation Notes

- Observability setup lives in `crates/{app}/src/observability.rs`.
- Cargo dependencies are in `crates/{app}/Cargo.toml`.
- `APP_ENV` defaults to `dev` when unset (OTel-enabled presets only).
- `OTEL_EXPORTER_OTLP_ENDPOINT` enables OTel export when set.
- `APP_LOG_PATH` overrides the full log file path.
- `APP_LOG_DIR` overrides the log directory.
- Default log path falls back to the user data directory when `/var/log` is not writable.
- Config file keys: `log_dir` and `otel_endpoint`.
- CLI flags `--quiet`/`--verbose` override the log level; otherwise `RUST_LOG` is honored.

> **Note**: `{app}` refers to your project name. Template paths use Copier conditionals
> (e.g., `{{project_name if has_cli else "__skip_cli__"}}`).

## Deep Links (Template Source)

These paths are in the template directory (conditional on `has_jsonl_logging` or `has_opentelemetry`):

- Observability setup: `template/crates/{app}/src/observability.rs.jinja`
- CLI entry point: `template/crates/{app}/src/main.rs.jinja`
- Dependencies: `template/crates/{app}/Cargo.toml.jinja`

## Anti-Patterns

- Switching back to pretty/text logging for default file output.
- Adding per-command ad-hoc log formatting that bypasses tracing.
- Writing to stdout (reserved for application output like MCP servers).

## Test Cases

- `cargo run -- info` writes JSONL lines with `timestamp`, `level`, `message`, and `target` to the log file.
- Span fields (e.g., `service`, `env`, `version`) propagate into log entries when logged inside a span.
- `RUST_LOG=debug cargo run -- info` increases verbosity without flags.
- `cargo run -- --quiet info` emits only `error` level events.

## Error Handling Matrix

| Scenario | Behavior | Message |
| --- | --- | --- |
| Log file path unwritable | Fallback to stderr logging | Warning to stderr |
| OTLP exporter init fails | Abort startup | Error from OpenTelemetry pipeline |
| Invalid OTEL endpoint | Abort startup | Error from OpenTelemetry pipeline |
