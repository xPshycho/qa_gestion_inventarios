import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import type {
  FullResult,
  Reporter,
  TestCase,
  TestResult,
} from '@playwright/test/reporter';

interface UxEvidenceReporterOptions {
  outputDir?: string;
}

interface EvidenceRecord {
  attachment: string;
  file: string;
  project: string;
  status: TestResult['status'];
  test: string;
}

const controlledEvidenceName = /^(a11y|responsive|browser|keyboard)-[A-Za-z0-9._-]+$/;

function safeName(value: string, maxLength = 120): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^A-Za-z0-9._-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, maxLength);
}

export default class UxEvidenceReporter implements Reporter {
  private readonly outputDir: string;
  private readonly records: EvidenceRecord[] = [];

  constructor(options: UxEvidenceReporterOptions = {}) {
    this.outputDir = path.resolve(options.outputDir ?? './ux-evidence');
  }

  async onTestEnd(test: TestCase, result: TestResult): Promise<void> {
    await mkdir(this.outputDir, { recursive: true, mode: 0o700 });

    const project = test.parent.project()?.name ?? 'unknown-project';
    let attachmentIndex = 0;

    for (const attachment of result.attachments) {
      if (
        !controlledEvidenceName.test(attachment.name)
        || attachment.contentType !== 'application/json'
        || !attachment.body
        || attachment.body.length > 2 * 1024 * 1024
      ) {
        continue;
      }

      try {
        JSON.parse(attachment.body.toString('utf8'));
      } catch {
        continue;
      }

      attachmentIndex += 1;
      const filename = [
        safeName(project),
        safeName(test.titlePath().join('-')),
        attachmentIndex,
        safeName(attachment.name),
      ].join('-') + '.json';

      await writeFile(path.join(this.outputDir, filename), attachment.body, {
        mode: 0o600,
      });
      this.records.push({
        attachment: attachment.name,
        file: filename,
        project,
        status: result.status,
        test: test.titlePath().join(' > '),
      });
    }
  }

  async onEnd(result: FullResult): Promise<void> {
    await mkdir(this.outputDir, { recursive: true, mode: 0o700 });
    const summary = {
      generatedAt: new Date().toISOString(),
      status: result.status,
      evidenceCount: this.records.length,
      evidence: this.records,
    };
    const markdown = [
      '# Evidencia automatizada de accesibilidad y UX',
      '',
      `- Estado Playwright: **${result.status}**`,
      `- Evidencias JSON: **${this.records.length}**`,
      `- Generado: \`${summary.generatedAt}\``,
      '',
      '| Proyecto | Prueba | Estado | Evidencia |',
      '|---|---|---|---|',
      ...this.records.map((record) => (
        `| ${record.project} | ${record.test.replaceAll('|', '\\|')} | ${record.status} | \`${record.file}\` |`
      )),
      '',
    ].join('\n');

    await Promise.all([
      writeFile(
        path.join(this.outputDir, 'summary.json'),
        JSON.stringify(summary, null, 2),
        { mode: 0o600 },
      ),
      writeFile(path.join(this.outputDir, 'summary.md'), markdown, {
        mode: 0o600,
      }),
    ]);
  }
}
