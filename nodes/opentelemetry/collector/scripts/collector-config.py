#!/usr/bin/env python3
"""Render and validate OpenTelemetry Collector config without third-party packages."""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def render_config(args: argparse.Namespace) -> str:
    exporters = []
    exporter_blocks = []

    if args.debug:
        exporters.append("debug")
        exporter_blocks.append(
            """  debug:
    verbosity: detailed"""
        )

    backend_endpoint = args.backend_endpoint or os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
    if backend_endpoint:
        exporters.append(f"{args.backend_type}/backend")
        if args.backend_type in {"otlphttp", "otlp_http"}:
            exporter_blocks.append(
                f"""  {args.backend_type}/backend:
    endpoint: {backend_endpoint}
    headers: {{}}"""
            )
        else:
            exporter_blocks.append(
                f"""  {args.backend_type}/backend:
    endpoint: {backend_endpoint}
    tls:
      insecure: {str(args.insecure).lower()}"""
            )

    if not exporters:
        exporters.append("debug")
        exporter_blocks.append(
            """  debug:
    verbosity: normal"""
        )

    exporter_list = ", ".join(exporters)
    exporter_yaml = "\n".join(exporter_blocks)
    metrics_host, metrics_port = split_host_port(args.telemetry_metrics_endpoint)

    return f"""receivers:
  otlp:
    protocols:
      grpc:
        endpoint: {args.bind}:4317
      http:
        endpoint: {args.bind}:4318

processors:
  memory_limiter:
    check_interval: 1s
    limit_mib: {args.memory_limit_mib}
  batch:
    timeout: {args.batch_timeout}

exporters:
{exporter_yaml}

extensions:
  health_check:
    endpoint: {args.health_endpoint}

service:
  extensions: [health_check]
  telemetry:
    metrics:
      readers:
        - pull:
            exporter:
              prometheus:
                host: '{metrics_host}'
                port: {metrics_port}
                without_type_suffix: true
                without_units: true
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [{exporter_list}]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [{exporter_list}]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [{exporter_list}]
"""


def cmd_render(args: argparse.Namespace) -> int:
    text = render_config(args)
    backend_endpoint = args.backend_endpoint or os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT")
    reported_exporters = []
    if args.debug or not backend_endpoint:
        reported_exporters.append("debug")
    if backend_endpoint:
        reported_exporters.append(f"{args.backend_type}/backend")
    if args.out:
        path = Path(args.out).resolve()
        if path.exists() and not args.force:
            print(f"Refusing to overwrite {path}; pass --force", file=sys.stderr)
            return 1
        path.write_text(text, encoding="utf-8")
        print(
            json.dumps(
                {
                    "configPath": str(path),
                    "pipelines": ["traces", "metrics", "logs"],
                    "exporters": reported_exporters,
                },
                indent=2,
            )
        )
    else:
        print(text, end="")
    return 0


def split_host_port(value: str) -> tuple[str, int]:
    if ":" not in value:
        raise ValueError("--telemetry-metrics-endpoint must be host:port")
    host, port = value.rsplit(":", 1)
    return host, int(port)


def cmd_validate(args: argparse.Namespace) -> int:
    if not args.config:
        print("--config is required for validate", file=sys.stderr)
        return 1

    binary = args.otelcol_bin or os.environ.get("OTELCOL_BIN", "otelcol")
    command = [binary, "validate", f"--config={args.config}"]
    completed = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    result = {
        "configPath": str(Path(args.config).resolve()),
        "valid": completed.returncode == 0,
        "command": command,
        "stdout": completed.stdout.strip(),
        "stderr": completed.stderr.strip(),
    }
    print(json.dumps(result, indent=2))
    return completed.returncode


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="action", required=True)

    render = sub.add_parser("render", help="render a baseline Collector YAML config")
    render.add_argument("--out", help="write config to this path; stdout when omitted")
    render.add_argument("--force", action="store_true", help="overwrite --out")
    render.add_argument("--bind", default="0.0.0.0", help="OTLP receiver bind address")
    render.add_argument("--debug", action="store_true", help="include detailed debug exporter")
    render.add_argument("--backend-endpoint", help="optional backend OTLP endpoint")
    render.add_argument(
        "--backend-type",
        default="otlphttp",
        choices=["otlphttp", "otlp", "otlp_http", "otlp_grpc"],
        help="backend exporter component type",
    )
    render.add_argument("--insecure", action="store_true", help="set insecure TLS for gRPC backend exporters")
    render.add_argument("--memory-limit-mib", type=int, default=512, help="memory_limiter limit_mib")
    render.add_argument("--batch-timeout", default="1s", help="batch processor timeout")
    render.add_argument("--health-endpoint", default="0.0.0.0:13133", help="health_check extension endpoint")
    render.add_argument(
        "--telemetry-metrics-endpoint",
        default="0.0.0.0:8888",
        help="Collector internal metrics endpoint",
    )
    render.set_defaults(func=cmd_render)

    validate = sub.add_parser("validate", help="run otelcol validate --config")
    validate.add_argument("--config", required=True, help="Collector config path")
    validate.add_argument("--otelcol-bin", help="Collector binary; defaults to OTELCOL_BIN or otelcol")
    validate.set_defaults(func=cmd_validate)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
