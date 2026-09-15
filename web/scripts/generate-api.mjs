import { spawnSync } from 'node:child_process';
import { readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
const output = join(root, 'src/app/api');
await rm(output, { recursive: true, force: true });
const result = spawnSync(process.execPath, [join(root, 'node_modules/ng-openapi-gen/lib/index.js')], {
  cwd: root,
  stdio: 'inherit',
});
if (result.error) throw result.error;
if (result.status !== 0) process.exit(result.status ?? 1);

// Normalize generator trailing whitespace without changing generated code.
for (const file of await readdir(output, { recursive: true })) {
  if (!file.endsWith('.ts')) continue;
  const path = join(output, file);
  const source = await readFile(path, 'utf8');
  await writeFile(path, `${source.trimEnd()}\n`);
}
