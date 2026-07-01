import { mkdir, copyFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const webRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(webRoot, '../..');
const publicDir = path.join(webRoot, 'public');
const appImagesDir = path.join(publicDir, 'images', 'app');
const brandDir = path.join(repoRoot, 'apps/mobile/assets/brand');
const readmeDir = path.join(repoRoot, 'apps/mobile/assets/readme');

const screenshotMap = [
  ['hero-dashboard.png', 'dashboard-cash-flow.webp'],
  ['02-dashboard.png', 'dashboard-health.webp'],
  ['03-accounts.png', 'accounts.webp'],
  ['04-budgets.png', 'budgets.webp'],
  ['05-rex-chat.png', 'rex-chat.webp'],
  ['06-knows.png', 'knows.webp'],
  ['07-goals.png', 'goals.webp'],
  ['08-voice.png', 'voice.webp'],
  ['09-transactions.png', 'transactions.webp'],
  ['10-profile-settings.png', 'profile-settings.webp'],
];

async function writeWebp(sourcePath, targetPath) {
  await sharp(sourcePath)
    .rotate()
    .resize({ width: 720, withoutEnlargement: true })
    .webp({ quality: 86 })
    .toFile(targetPath);
}

async function writeLogo(sourcePath, targetPath, size) {
  await sharp(sourcePath)
    .resize(size, size, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toFile(targetPath);
}

async function writeOgImage() {
  const heroPath = path.join(readmeDir, 'hero-dashboard.png');
  await sharp({
    create: {
      width: 1200,
      height: 630,
      channels: 4,
      background: { r: 8, g: 24, b: 39, alpha: 1 },
    },
  })
    .composite([
      {
        input: await sharp(heroPath).rotate().resize({ height: 560, withoutEnlargement: true }).toBuffer(),
        gravity: 'east',
      },
      {
        input: Buffer.from(`
          <svg width="620" height="630">
            <text x="48" y="150" fill="#ffffff" font-family="Inter, Arial, sans-serif" font-size="54" font-weight="700">Clarity</text>
            <text x="48" y="220" fill="#9fd9c9" font-family="Inter, Arial, sans-serif" font-size="28" font-weight="600">Money, memory, and Rex — in one calm place.</text>
            <text x="48" y="280" fill="#b8c5d1" font-family="Inter, Arial, sans-serif" font-size="22">Privacy-first · User-authorized accounts · Dark UI</text>
          </svg>
        `),
        gravity: 'west',
      },
    ])
    .jpeg({ quality: 88 })
    .toFile(path.join(publicDir, 'og-image.jpg'));
}

await mkdir(appImagesDir, { recursive: true });

for (const [sourceName, targetName] of screenshotMap) {
  const sourcePath = path.join(readmeDir, sourceName);
  const targetPath = path.join(appImagesDir, targetName);
  await writeWebp(sourcePath, targetPath);
  console.log(`screenshot: ${targetName}`);
}

const markSource = path.join(brandDir, 'clarity_mark.png');
await writeLogo(markSource, path.join(publicDir, 'clarity-mark-96.png'), 96);
await writeLogo(markSource, path.join(publicDir, 'clarity-mark-192.png'), 192);
await writeLogo(path.join(brandDir, 'clarity_source_logo.png'), path.join(publicDir, 'clarity-logo.png'), 512);
console.log('logos updated');

await writeOgImage();
console.log('og-image updated');
