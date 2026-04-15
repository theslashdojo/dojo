#!/usr/bin/env node
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';

const REQUIRED_PACKAGES = [
  '@opentelemetry/api',
  '@opentelemetry/sdk-node',
  '@opentelemetry/auto-instrumentations-node',
  '@opentelemetry/exporter-trace-otlp-http',
  '@opentelemetry/exporter-metrics-otlp-http',
  '@opentelemetry/sdk-metrics',
  '@opentelemetry/resources',
  '@opentelemetry/semantic-conventions'
];

function usage() {
  return `Usage:
  node create-node-bootstrap.mjs --service-name <name> [options]

Options:
  --service-name <name>       service.name value (default: package.json name or OTEL_SERVICE_NAME)
  --service-version <version> service.version value (default: package.json version or 0.0.0)
  --endpoint <url>            OTLP/HTTP base endpoint (default: http://localhost:4318)
  --out <path>                output path (default: instrumentation.mjs)
  --force                     overwrite an existing file
  --dry-run                   print generated file instead of writing
  --print-packages            print required npm packages
  --help                      show this help
`;
}

function parseArgs(argv) {
  const options = {
    endpoint: 'http://localhost:4318',
    out: 'instrumentation.mjs',
    force: false,
    dryRun: false,
    printPackages: false
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') options.help = true;
    else if (arg === '--force') options.force = true;
    else if (arg === '--dry-run') options.dryRun = true;
    else if (arg === '--print-packages') options.printPackages = true;
    else if (arg === '--service-name') options.serviceName = argv[++i];
    else if (arg === '--service-version') options.serviceVersion = argv[++i];
    else if (arg === '--endpoint') options.endpoint = argv[++i];
    else if (arg === '--out') options.out = argv[++i];
    else throw new Error(`Unknown argument: ${arg}`);
  }

  return options;
}

function readPackageDefaults(cwd) {
  const pkgPath = resolve(cwd, 'package.json');
  if (!existsSync(pkgPath)) return {};
  try {
    const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
    return {
      serviceName: typeof pkg.name === 'string' ? pkg.name.replace(/^@/, '').replace('/', '-') : undefined,
      serviceVersion: typeof pkg.version === 'string' ? pkg.version : undefined
    };
  } catch {
    return {};
  }
}

function jsString(value) {
  return JSON.stringify(String(value));
}

function renderBootstrap({ serviceName, serviceVersion, endpoint }) {
  return `import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-http';
import { OTLPMetricExporter } from '@opentelemetry/exporter-metrics-otlp-http';
import { PeriodicExportingMetricReader } from '@opentelemetry/sdk-metrics';
import { resourceFromAttributes } from '@opentelemetry/resources';
import {
  ATTR_SERVICE_NAME,
  ATTR_SERVICE_VERSION
} from '@opentelemetry/semantic-conventions';

const endpoint = (process.env.OTEL_EXPORTER_OTLP_ENDPOINT || ${jsString(endpoint)}).replace(/\\/$/, '');

const traceExporter = new OTLPTraceExporter({
  url: process.env.OTEL_EXPORTER_OTLP_TRACES_ENDPOINT || endpoint + '/v1/traces'
});

const metricReader = new PeriodicExportingMetricReader({
  exporter: new OTLPMetricExporter({
    url: process.env.OTEL_EXPORTER_OTLP_METRICS_ENDPOINT || endpoint + '/v1/metrics'
  })
});

const sdk = new NodeSDK({
  resource: resourceFromAttributes({
    [ATTR_SERVICE_NAME]: process.env.OTEL_SERVICE_NAME || ${jsString(serviceName)},
    [ATTR_SERVICE_VERSION]: process.env.OTEL_SERVICE_VERSION || ${jsString(serviceVersion)}
  }),
  traceExporter,
  metricReader,
  instrumentations: [getNodeAutoInstrumentations()]
});

sdk.start();

async function shutdown(signal) {
  try {
    await sdk.shutdown();
  } catch (error) {
    console.error('OpenTelemetry shutdown failed:', error);
  } finally {
    process.kill(process.pid, signal);
  }
}

process.once('SIGTERM', () => shutdown('SIGTERM'));
process.once('SIGINT', () => shutdown('SIGINT'));
`;
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(usage());
    return;
  }

  if (options.printPackages) {
    process.stdout.write(`${REQUIRED_PACKAGES.join(' ')}\n`);
    return;
  }

  const defaults = readPackageDefaults(process.cwd());
  const serviceName = options.serviceName || process.env.OTEL_SERVICE_NAME || defaults.serviceName;
  if (!serviceName) {
    throw new Error('Missing --service-name and no package.json name or OTEL_SERVICE_NAME was found');
  }

  const serviceVersion = options.serviceVersion || defaults.serviceVersion || '0.0.0';
  const output = resolve(process.cwd(), options.out);
  const source = renderBootstrap({
    serviceName,
    serviceVersion,
    endpoint: options.endpoint
  });

  if (options.dryRun) {
    process.stdout.write(source);
    return;
  }

  if (existsSync(output) && !options.force) {
    throw new Error(`Refusing to overwrite ${output}; pass --force to replace it`);
  }

  if (!existsSync(dirname(output))) {
    throw new Error(`Output directory does not exist: ${dirname(output)}`);
  }

  writeFileSync(output, source);
  process.stdout.write(JSON.stringify({
    path: output,
    packages: REQUIRED_PACKAGES,
    runCommand: `OTEL_EXPORTER_OTLP_ENDPOINT=${options.endpoint} node --import ${options.out} ./server.js`
  }, null, 2) + '\n');
}

try {
  main();
} catch (error) {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
}
