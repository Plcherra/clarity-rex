import { mkdir, unlink } from 'node:fs/promises';
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

/** Latest device captures (IMG_*) mapped to landing page assets. */
const screenshotMap = [
  ['IMG_2025.PNG', 'dashboard-cash-flow.webp'],
  ['IMG_2029.PNG', 'dashboard-health.webp'],
  ['IMG_2031.PNG', 'accounts.webp'],
  ['IMG_2032.PNG', 'budgets.webp'],
  ['IMG_2034.PNG', 'rex-chat.webp'],
  ['IMG_2036.PNG', 'knows.webp'],
  ['IMG_2043.PNG', 'goals.webp'],
  ['IMG_2040.PNG', 'voice.webp'],
  ['IMG_2028.PNG', 'transactions.webp'],
  ['10-profile-settings.png', 'profile-settings.webp'],
];

const retiredAssets = [
  'assistant-home.webp',
  'category-management.webp',
  'conversations.webp',
  'memory.webp',
];

async function writeWebp(sourcePath, targetPath) {
  await sharp(sourcePath)
    .rotate()
    .resize({ width: 720, withoutEnlargement: true })
    .webp({ quality: 88 })
    .toFile(targetPath);
}

async function writeLogo(sourcePath, targetPath, size) {
  await sharp(sourcePath)
    .resize(size, size, { fit: 'contain', background: { r: 255, g: 255, b: 255, alpha: 1 } })
    .png()
    .toFile(targetPath);
}

async function writeOgImage() {
  const heroPath = path.join(readmeDir, 'IMG_2025.PNG');
  await sharp({
    create: {
      width: 1200,
      height: 630,
      channels: 4,
      background: { r: 255, g: 255, b: 255, alpha: 1 },
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
            <text x="48" y="150" fill="#081827" font-family="Inter, Arial, sans-serif" font-size="54" font-weight="700">Clarity</text>
            <text x="48" y="220" fill="#0f7d68" font-family="Inter, Arial, sans-serif" font-size="28" font-weight="600">Money, memory, and Rex — in one calm place.</text>
            <text x="48" y="280" fill="#3f5163" font-family="Inter, Arial, sans-serif" font-size="22">Privacy-first · iPhone · Android · Web</text>
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
  console.log(`screenshot: ${targetName} <- ${sourceName}`);
}

for (const fileName of retiredAssets) {
  try {
    await unlink(path.join(appImagesDir, fileName));
    console.log(`removed stale asset: ${fileName}`);
  } catch {
    // already gone
  }
}

const iconSource = path.join(brandDir, 'clarity_app_icon.png');
await writeLogo(iconSource, path.join(publicDir, 'clarity-mark-96.png'), 96);
await writeLogo(iconSource, path.join(publicDir, 'clarity-mark-192.png'), 192);
await writeLogo(iconSource, path.join(publicDir, 'clarity-logo.png'), 512);
console.log('logos updated from clarity_app_icon.png');

await writeOgImage();
console.log('og-image updated');
