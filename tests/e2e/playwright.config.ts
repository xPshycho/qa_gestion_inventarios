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
const uxEvidenceOutputDir =
  process.env.PLAYWRIGHT_UX_EVIDENCE_DIR ?? './ux-evidence';
const chromiumLaunchOptions = executablePath
  ? { launchOptions: { executablePath } }
  : {};
const responsiveSpec = /responsive\.spec\.ts/;
const browserCompatibilitySpec = /browser-compatibility\.spec\.ts/;

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
        ['./ux-evidence-reporter.ts', { outputDir: uxEvidenceOutputDir }],
      ]
    : [
        ['list'],
        ['html', { outputFolder: htmlOutputDir, open: 'never' }],
        ['junit', { outputFile: junitOutputFile }],
        ['./ux-evidence-reporter.ts', { outputDir: uxEvidenceOutputDir }],
      ],
  use: {
    baseURL,
    actionTimeout: 15_000,
    navigationTimeout: 30_000,
    screenshot: safeReporting ? 'off' : 'only-on-failure',
    trace: retainSensitiveArtifacts ? 'retain-on-failure' : 'off',
    video: retainSensitiveArtifacts ? 'retain-on-failure' : 'off',
  },
  projects: [
    {
      name: 'chromium',
      testIgnore: [responsiveSpec, browserCompatibilitySpec],
      use: {
        ...devices['Desktop Chrome'],
        ...chromiumLaunchOptions,
      },
    },
    {
      name: 'browser-chromium',
      testMatch: browserCompatibilitySpec,
      use: {
        ...devices['Desktop Chrome'],
        ...chromiumLaunchOptions,
      },
    },
    {
      name: 'browser-firefox',
      testMatch: browserCompatibilitySpec,
      use: {
        ...devices['Desktop Firefox'],
      },
    },
    {
      name: 'browser-webkit',
      testMatch: browserCompatibilitySpec,
      use: {
        ...devices['Desktop Safari'],
      },
    },
    {
      name: 'responsive-mobile',
      testMatch: responsiveSpec,
      use: {
        ...devices['Pixel 7'],
        ...chromiumLaunchOptions,
      },
    },
    {
      name: 'responsive-tablet',
      testMatch: responsiveSpec,
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 768, height: 1024 },
        hasTouch: true,
        ...chromiumLaunchOptions,
      },
    },
    {
      name: 'responsive-desktop',
      testMatch: responsiveSpec,
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: 1440, height: 900 },
        ...chromiumLaunchOptions,
      },
    },
  ],
});
