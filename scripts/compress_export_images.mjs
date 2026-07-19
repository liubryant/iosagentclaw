import { readdir, stat, rename, unlink, readFile, writeFile } from 'node:fs/promises';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import path from 'node:path';

const run = promisify(execFile);
const root = '/Users/liuzheng/Desktop/Midjourney_Top_Export';
const imageDir = path.join(root, 'images');
const maxBytes = 400 * 1024;
const files = (await readdir(imageDir)).filter(name => /\.(png|jpe?g)$/i.test(name));
const replacements = new Map();

for (let index = 0; index < files.length; index++) {
  const oldName = files[index];
  const source = path.join(imageDir, oldName);
  const base = oldName.replace(/\.[^.]+$/, '');
  const finalName = `${base}.jpg`;
  const finalPath = path.join(imageDir, finalName);
  let low = 20;
  let high = 95;
  let bestPath = '';
  let bestQuality = 0;

  while (low <= high) {
    const quality = Math.floor((low + high) / 2);
    const candidate = path.join('/private/tmp', `mj-compress-${process.pid}-${index}-${quality}.jpg`);
    await run('/usr/bin/sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', String(quality), source, '--out', candidate]);
    const size = (await stat(candidate)).size;
    if (size <= maxBytes) {
      if (bestPath) await unlink(bestPath).catch(() => {});
      bestPath = candidate;
      bestQuality = quality;
      low = quality + 1;
    } else {
      await unlink(candidate).catch(() => {});
      high = quality - 1;
    }
  }

  if (!bestPath) {
    bestPath = path.join('/private/tmp', `mj-compress-${process.pid}-${index}-minimum.jpg`);
    await run('/usr/bin/sips', ['-s', 'format', 'jpeg', '-s', 'formatOptions', '15', source, '--out', bestPath]);
    bestQuality = 15;
  }

  if (source !== finalPath) await unlink(finalPath).catch(() => {});
  await rename(bestPath, finalPath);
  if (source !== finalPath) await unlink(source);
  replacements.set(oldName, finalName);
  const finalSize = (await stat(finalPath)).size;
  console.log(`${index + 1}/${files.length} ${finalName} ${(finalSize / 1024).toFixed(1)}KB Q${bestQuality}`);
}

for (const filename of ['metadata.json', 'prompts.csv', 'prompts.md']) {
  const filePath = path.join(root, filename);
  let content;
  try { content = await readFile(filePath, 'utf8'); } catch { continue; }
  for (const [oldName, newName] of replacements) content = content.replaceAll(oldName, newName);
  await writeFile(filePath, content);
}

console.log(`压缩完成：${files.length} 张`);
