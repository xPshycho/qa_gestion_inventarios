#!/usr/bin/env node

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import process from "node:process";

const documentation = [
  "README.md",
  "docs/deployment/gcp-managed-environments.md",
  "docs/deployment/opentofu-gcp.md",
  "infra/opentofu/README.md",
  "infra/opentofu/environments/README.md",
  "infra/opentofu/platform/README.md",
  "scripts/opentofu/README.md",
  ".github/workflows/README.md",
  ...readdirSync("infra/opentofu/modules", { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => `infra/opentofu/modules/${entry.name}/README.md`)
    .filter(existsSync),
];

const markdownLink = /!?\[[^\]]*]\(([^)]+)\)/g;
const failures = [];

for (const file of documentation) {
  const content = readFileSync(file, "utf8");

  for (const match of content.matchAll(markdownLink)) {
    const rawTarget = match[1].trim().replace(/^<|>$/g, "");
    const target = decodeURI(rawTarget.split("#", 1)[0].split("?", 1)[0]);

    if (
      target === "" ||
      target.startsWith("http://") ||
      target.startsWith("https://") ||
      target.startsWith("mailto:")
    ) {
      continue;
    }

    const resolved = resolve(dirname(file), target);
    if (!existsSync(resolved)) {
      failures.push(`${file}: enlace local inexistente: ${rawTarget}`);
    }
  }
}

if (failures.length > 0) {
  console.error(failures.join("\n"));
  process.exit(1);
}

console.log(`Validated local links in ${documentation.length} infrastructure documents.`);
