import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import type {
  Reporter,
  TestCase,
  TestResult,
} from '@playwright/test/reporter';

const controlledScreenshotNames = new Set([
  'acceso-denegado-productos',
  'auditoria-producto',
  'auditoria-stock',
  'catalogo-movil',
  'catalogo-solo-lectura',
  'movimientos-stock',
  'producto-actualizado',
  'producto-creado',
  'producto-eliminado',
  'sesion-administrador',
  'sesion-cerrada',
]);
const pngSignature = Buffer.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
]);
const issue90ScreenshotName = /^(responsive|browser|keyboard)-[A-Za-z0-9._-]+$/;

interface SafeScreenshotReporterOptions {
  outputDir?: string;
}

export default class SafeScreenshotReporter implements Reporter {
  private readonly outputDir: string;

  constructor(options: SafeScreenshotReporterOptions = {}) {
    this.outputDir = path.resolve(options.outputDir ?? './safe-screenshots');
  }

  async onTestEnd(test: TestCase, result: TestResult): Promise<void> {
    await mkdir(this.outputDir, { recursive: true, mode: 0o700 });

    let attachmentIndex = 0;
    for (const attachment of result.attachments) {
      if (
        (!controlledScreenshotNames.has(attachment.name)
          && !issue90ScreenshotName.test(attachment.name))
        || attachment.contentType !== 'image/png'
        || !attachment.body
        || attachment.body.length > 10 * 1024 * 1024
        || !attachment.body.subarray(0, pngSignature.length).equals(pngSignature)
      ) {
        continue;
      }

      attachmentIndex += 1;
      const testName = test.titlePath()
        .join('-')
        .normalize('NFKD')
        .replace(/[\u0300-\u036f]/g, '')
        .replace(/[^A-Za-z0-9._-]+/g, '-')
        .replace(/^-+|-+$/g, '')
        .slice(0, 100);
      const attachmentName = attachment.name.replace(/[^A-Za-z0-9._-]+/g, '-');
      const filename = `${testName}-${attachmentIndex}-${attachmentName}.png`;

      await writeFile(
        path.join(this.outputDir, filename),
        attachment.body,
        { mode: 0o600 },
      );
    }
  }
}
