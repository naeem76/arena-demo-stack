import { mkdir, writeFile } from 'node:fs/promises';

const baseUrl = process.env['API_BASE_URL'] ?? 'http://localhost:18080';
const response = await fetch(new URL('/v3/api-docs', baseUrl));
if (!response.ok) throw new Error(`OpenAPI export failed: HTTP ${response.status}`);
const specification = await response.json();
await mkdir(new URL('../contracts/', import.meta.url), { recursive: true });
await writeFile(new URL('../contracts/openapi.json', import.meta.url), `${JSON.stringify(specification, null, 2)}\n`);
console.log('Updated contracts/openapi.json');
