import { defineConfig, devices } from '@playwright/test';

const baseURL = process.env.E2E_BASE_URL ?? 'http://localhost:5173';
const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH;
const junitOutputFile =
  process.env.PLAYWRIGHT_JUNIT_OUTPUT_NAME ?? 'test-results/playwright-results.xml';
const outputDir =
  process.env.PLAYWRIGHT_OUTPUT_DIR ?? './test-results';
const htmlOutputDir =
  process.env.PLAYWRIGHT_HTML_OUTPUT_DIR ?? './playwright-report';
const retainSensitiveArtifacts =
  process.env.PLAYWRIGHT_RETAIN_SENSITIVE_ARTIFACTS !== 'false';
const safeReporting = process.env.PLAYWRIGHT_SAFE_REPORTING === 'true';
const safeScreenshotOutputDir =
  process.env.PLAYWRIGHT_SAFE_SCREENSHOT_DIR ?? './safe-screenshots';

export default defineConfig({
  testDir: './specs',
  outputDir,
  fullyParallel: false,
  workers: 1,
  timeout: 45_000,
  expect: {
    timeout: 10_000,
  },
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 1 : 0,
  reporter: safeReporting
    ? [
        ['list'],
        ['junit', { outputFile: junitOutputFile }],
        ['./safe-screenshot-reporter.ts', { outputDir: safeScreenshotOutputDir }],
      ]
    : [
        ['list'],
        ['html', { outputFolder: htmlOutputDir, open: 'never' }],
        ['junit', { outputFile: junitOutputFile }],
      ],
  use: {
    baseURL,
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    screenshot: safeReporting ? 'off' : 'only-on-failure',
    trace: retainSensitiveArtifacts ? 'retain-on-failure' : 'off',
    video: retainSensitiveArtifacts ? 'retain-on-failure' : 'off',
    launchOptions: executablePath ? { executablePath } : undefined,
  },
  projects: [
    {
      name: 'chromium',
      testIgnore: /responsive\.spec\.ts/,
      use: {
        ...devices['Desktop Chrome'],
      },
    },
    {
      name: 'mobile-chromium',
      testMatch: /responsive\.spec\.ts/,
      use: {
        ...devices['Pixel 7'],
      },
    },
  ],
});
