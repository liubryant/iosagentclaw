import { readdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const root = '/Users/liuzheng/Desktop/Midjourney_Top_Export';
const imageDir = path.join(root, 'images');
const imageNames = (await readdir(imageDir))
  .filter(name => /\.(jpe?g|png|webp)$/i.test(name))
  .sort();
const metadata = JSON.parse(await readFile(path.join(root, 'metadata.json'), 'utf8'));
const byFilename = new Map(metadata.map(item => [item.filename, item]));
const result = imageNames.map(filename => ({
  image: filename,
  prompt_zh: byFilename.get(filename)?.chinesePrompt || ''
}));

await writeFile(
  path.join(root, 'image_prompts_zh.json'),
  JSON.stringify(result, null, 2) + '\n'
);
console.log(`JSON 生成完成：${result.length} 条，缺失中文 prompt：${result.filter(item => !item.prompt_zh).length}`);
