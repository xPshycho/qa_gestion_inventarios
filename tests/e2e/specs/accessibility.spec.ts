import AxeBuilder from '@axe-core/playwright';
import { expect, Page, test, TestInfo } from '@playwright/test';
import { adminUser, loginAs } from '../helpers/auth';

interface CriticalView {
  heading: string;
  name: string;
  route: string;
}

async function waitForView(page: Page, heading: string): Promise<void> {
  await expect(page.getByRole('heading', { name: heading, exact: true }))
    .toBeVisible();
  await expect(page.locator('mat-progress-bar')).toHaveCount(0);
}

async function scanCriticalView(
  page: Page,
  testInfo: TestInfo,
  view: CriticalView,
): Promise<void> {
  await page.goto(view.route);
  await waitForView(page, view.heading);

  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
    .analyze();
  const blockingViolations = results.violations.filter(
    (violation) => violation.impact === 'critical' || violation.impact === 'serious',
  );
  const evidence = {
    generatedAt: new Date().toISOString(),
    screen: view.name,
    url: page.url(),
    violations: results.violations.map((violation) => ({
      id: violation.id,
      impact: violation.impact,
      help: violation.help,
      helpUrl: violation.helpUrl,
      nodes: violation.nodes.map((node) => ({
        target: node.target,
        failureSummary: node.failureSummary,
      })),
    })),
    blockingViolationCount: blockingViolations.length,
  };

  await testInfo.attach(`a11y-${view.name}`, {
    body: Buffer.from(JSON.stringify(evidence, null, 2)),
    contentType: 'application/json',
  });
  expect(
    blockingViolations,
    `Violaciones críticas o serias en ${view.name}:\n${JSON.stringify(evidence.violations, null, 2)}`,
  ).toEqual([]);
}

test('valida WCAG AA en las seis pantallas críticas', async ({
  page,
}, testInfo) => {
  await scanCriticalView(page, testInfo, {
    name: 'login',
    route: '/login',
    heading: 'Gestión de inventarios',
  });

  await loginAs(page, adminUser);
  await page.goto('/productos');
  await waitForView(page, 'Catálogo de inventario');

  const stockRoute = await page.getByRole('link', { name: 'Movimientos' })
    .first()
    .getAttribute('href');
  const auditRoute = await page.getByRole('link', { name: 'Auditoría' })
    .first()
    .getAttribute('href');
  expect(stockRoute).toBeTruthy();
  expect(auditRoute).toBeTruthy();

  const authenticatedViews: CriticalView[] = [
    { name: 'dashboard', route: '/dashboard', heading: 'Inventario operativo' },
    { name: 'productos', route: '/productos', heading: 'Catálogo de inventario' },
    { name: 'stock', route: stockRoute!, heading: 'Movimientos de stock' },
    { name: 'auditoria', route: auditRoute!, heading: 'Historial de producto y stock' },
    { name: 'seguridad', route: '/seguridad', heading: 'Usuarios, roles y permisos' },
  ];

  for (const view of authenticatedViews) {
    await scanCriticalView(page, testInfo, view);
  }
});
