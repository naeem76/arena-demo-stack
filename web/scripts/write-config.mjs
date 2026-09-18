import { writeFile } from 'node:fs/promises';

const apiBaseUrl = process.env['API_BASE_URL'] ?? 'http://localhost:18080';
const issuerUrl = process.env['AUTH_ISSUER_URL'] ?? apiBaseUrl;
await writeFile(new URL('../public/config.json', import.meta.url), `${JSON.stringify({ apiBaseUrl, issuerUrl })}\n`);
