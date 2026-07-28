function metricValues(data, name) {
  const metric = data.metrics[name];
  return metric && metric.values ? metric.values : {};
}

function value(data, metricName, valueName) {
  const values = metricValues(data, metricName);
  return values[valueName] === undefined ? null : values[valueName];
}

function endpointSummary(data, endpoint) {
  const prefix = `endpoint_${endpoint}`;

  return {
    requests: value(data, `${prefix}_requests`, 'count'),
    requestsPerSecond: value(data, `${prefix}_requests`, 'rate'),
    errorRate: value(data, `${prefix}_failed`, 'rate'),
    avgMs: value(data, `${prefix}_duration`, 'avg'),
    p90Ms: value(data, `${prefix}_duration`, 'p(90)'),
    p95Ms: value(data, `${prefix}_duration`, 'p(95)'),
    p99Ms: value(data, `${prefix}_duration`, 'p(99)'),
  };
}

function collectThresholds(data) {
  const thresholds = [];

  Object.keys(data.metrics).forEach((metricName) => {
    const metric = data.metrics[metricName];
    const metricThresholds = metric.thresholds || {};

    Object.keys(metricThresholds).forEach((threshold) => {
      thresholds.push({
        metric: metricName,
        threshold,
        ok: Boolean(metricThresholds[threshold].ok),
      });
    });
  });

  return thresholds;
}

function rounded(valueToRound, digits = 2) {
  if (valueToRound === null || valueToRound === undefined || Number.isNaN(valueToRound)) {
    return null;
  }

  const factor = 10 ** digits;
  return Math.round(valueToRound * factor) / factor;
}

function format(valueToFormat, suffix = '') {
  const roundedValue = rounded(valueToFormat);
  return roundedValue === null ? 'n/a' : `${roundedValue}${suffix}`;
}

function percent(valueToFormat) {
  return valueToFormat === null || valueToFormat === undefined
    ? 'n/a'
    : `${format(valueToFormat * 100, '%')}`;
}

export function normalizeSummary(data, context) {
  const thresholds = collectThresholds(data);

  return {
    generatedAt: new Date().toISOString(),
    profile: context.profile,
    baseUrl: context.baseUrl,
    paths: {
      health: context.healthPath,
      products: context.productsPath,
      reports: context.reportsPath,
    },
    durationSeconds: data.state && data.state.testRunDurationMs
      ? rounded(data.state.testRunDurationMs / 1000)
      : null,
    vusMax: value(data, 'vus_max', 'value'),
    iterations: value(data, 'iterations', 'count'),
    requests: value(data, 'http_reqs', 'count'),
    requestsPerSecond: value(data, 'http_reqs', 'rate'),
    errorRate: value(data, 'http_req_failed', 'rate'),
    checksRate: value(data, 'checks', 'rate'),
    latency: {
      avgMs: value(data, 'http_req_duration', 'avg'),
      p90Ms: value(data, 'http_req_duration', 'p(90)'),
      p95Ms: value(data, 'http_req_duration', 'p(95)'),
      p99Ms: value(data, 'http_req_duration', 'p(99)'),
    },
    endpoints: {
      health: endpointSummary(data, 'health'),
      products: endpointSummary(data, 'products'),
      reports: endpointSummary(data, 'reports'),
      auth: endpointSummary(data, 'auth'),
    },
    thresholds,
    thresholdsPassed: thresholds.length === 0 ? null : thresholds.every((threshold) => threshold.ok),
  };
}

export function renderText(summary) {
  const lines = [
    '',
    'k6 performance summary',
    `Profile: ${summary.profile}`,
    `Generated at: ${summary.generatedAt}`,
    `Base URL: ${summary.baseUrl}`,
    `Duration: ${format(summary.durationSeconds, 's')}`,
    `VUs max: ${format(summary.vusMax)}`,
    `Iterations: ${format(summary.iterations)}`,
    `Requests: ${format(summary.requests)}`,
    `Requests/s: ${format(summary.requestsPerSecond)}`,
    `Error rate: ${percent(summary.errorRate)}`,
    `Checks passed: ${percent(summary.checksRate)}`,
    `Latency avg: ${format(summary.latency.avgMs, 'ms')}`,
    `Latency p90: ${format(summary.latency.p90Ms, 'ms')}`,
    `Latency p95: ${format(summary.latency.p95Ms, 'ms')}`,
    `Latency p99: ${format(summary.latency.p99Ms, 'ms')}`,
    `Thresholds: ${summary.thresholdsPassed === true ? 'PASS' : 'FAIL'}`,
    '',
    'Endpoint metrics:',
  ];

  Object.keys(summary.endpoints).forEach((endpoint) => {
    const metric = summary.endpoints[endpoint];
    lines.push(
      `- ${endpoint}: requests=${format(metric.requests)}, errorRate=${percent(metric.errorRate)}, `
      + `avg=${format(metric.avgMs, 'ms')}, p90=${format(metric.p90Ms, 'ms')}, `
      + `p95=${format(metric.p95Ms, 'ms')}, p99=${format(metric.p99Ms, 'ms')}`,
    );
  });

  lines.push('');
  lines.push('Threshold details:');
  summary.thresholds.forEach((threshold) => {
    lines.push(`- ${threshold.ok ? 'PASS' : 'FAIL'} ${threshold.metric}: ${threshold.threshold}`);
  });
  lines.push('');

  return `${lines.join('\n')}\n`;
}

export function renderMarkdown(summary) {
  const rows = Object.keys(summary.endpoints)
    .map((endpoint) => {
      const metric = summary.endpoints[endpoint];
      return `| ${endpoint} | ${format(metric.requests)} | ${format(metric.requestsPerSecond)} | ${percent(metric.errorRate)} | ${format(metric.avgMs, 'ms')} | ${format(metric.p90Ms, 'ms')} | ${format(metric.p95Ms, 'ms')} | ${format(metric.p99Ms, 'ms')} |`;
    })
    .join('\n');

  const thresholdRows = summary.thresholds
    .map((threshold) => `| ${threshold.metric} | ${threshold.threshold} | ${threshold.ok ? 'PASS' : 'FAIL'} |`)
    .join('\n');

  return `# k6 performance summary

Generated at: ${summary.generatedAt}

Profile: \`${summary.profile}\`

Base URL: \`${summary.baseUrl}\`

## Global metrics

| Metric | Value |
|---|---:|
| Duration | ${format(summary.durationSeconds, 's')} |
| VUs max | ${format(summary.vusMax)} |
| Iterations | ${format(summary.iterations)} |
| Requests | ${format(summary.requests)} |
| Requests/s | ${format(summary.requestsPerSecond)} |
| Error rate | ${percent(summary.errorRate)} |
| Checks passed | ${percent(summary.checksRate)} |
| Latency avg | ${format(summary.latency.avgMs, 'ms')} |
| Latency p90 | ${format(summary.latency.p90Ms, 'ms')} |
| Latency p95 | ${format(summary.latency.p95Ms, 'ms')} |
| Latency p99 | ${format(summary.latency.p99Ms, 'ms')} |
| Thresholds | ${summary.thresholdsPassed === true ? 'PASS' : 'FAIL'} |

## Endpoint metrics

| Endpoint | Requests | Requests/s | Error rate | Avg | p90 | p95 | p99 |
|---|---:|---:|---:|---:|---:|---:|---:|
${rows}

## Thresholds

| Metric | Threshold | Result |
|---|---|---|
${thresholdRows}
`;
}

export function buildSummaryOutput(data, context) {
  const summary = normalizeSummary(data, context);

  return {
    stdout: renderText(summary),
    [`${context.resultsDir}/k6-summary.json`]: JSON.stringify(summary, null, 2),
    [`${context.resultsDir}/k6-summary.md`]: renderMarkdown(summary),
  };
}
