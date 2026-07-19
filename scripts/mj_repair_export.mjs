import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const ROOT = '/Users/liuzheng/Desktop/Midjourney_Top_Export';
const IMAGE_DIR = path.join(ROOT, 'images');
const items = JSON.parse(await readFile(path.join(ROOT, 'metadata.json'), 'utf8'));
const sleep = (ms) => new Promise(resolve => setTimeout(resolve, ms));

const tabs = await (await fetch('http://127.0.0.1:9223/json/list')).json();
const page = tabs.find(tab => tab.type === 'page' && tab.url.includes('midjourney.com'));
if (!page) throw new Error('没有找到 Midjourney 浏览器页面');
const ws = new WebSocket(page.webSocketDebuggerUrl);
let nextId = 1;
const pending = new Map();
const send = (method, params = {}) => {
  const id = nextId++;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
};
ws.onmessage = event => {
  const msg = JSON.parse(event.data);
  if (!msg.id || !pending.has(msg.id)) return;
  const entry = pending.get(msg.id);
  pending.delete(msg.id);
  msg.error ? entry.reject(new Error(msg.error.message)) : entry.resolve(msg.result);
};
await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
await send('Runtime.enable');

async function browserDownload(url) {
  const expression = `(async () => {
    const response = await fetch(${JSON.stringify(url)}, { credentials: 'include', cache: 'force-cache' });
    if (!response.ok) return { error: 'HTTP ' + response.status };
    const bytes = new Uint8Array(await response.arrayBuffer());
    let binary = '';
    const size = 0x8000;
    for (let i = 0; i < bytes.length; i += size) binary += String.fromCharCode(...bytes.subarray(i, i + size));
    return { base64: btoa(binary), type: response.headers.get('content-type') || 'image/webp' };
  })()`;
  const out = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (out.exceptionDetails) return { error: out.exceptionDetails.exception?.description || '浏览器下载失败' };
  return out.result.value;
}

for (let i = 0; i < items.length; i++) {
  const item = items[i];
  const result = await browserDownload(item.imageUrl);
  if (result?.base64) {
    const ext = result.type.includes('png') ? 'png' : result.type.includes('jpeg') ? 'jpg' : 'webp';
    item.filename = `${String(i + 1).padStart(3, '0')}_${item.jobId}_${item.imageIndex}.${ext}`;
    item.sourceImageUrl = item.imageUrl;
    delete item.downloadError;
    await writeFile(path.join(IMAGE_DIR, item.filename), Buffer.from(result.base64, 'base64'));
  } else {
    item.downloadError = result?.error || '浏览器下载失败';
  }
  console.log(`浏览器下载：${i + 1}/${items.length}`);
}
ws.close();

async function translate(text) {
  if (!text || !/[A-Za-z]/.test(text)) return text;
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const url = new URL('https://api.mymemory.translated.net/get');
      url.search = new URLSearchParams({ q: text.slice(0, 490), langpair: 'en|zh-CN' });
      const response = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
      const data = await response.json();
      if (data.responseStatus === 200 && data.responseData?.translatedText) return data.responseData.translatedText;
    } catch {}
    await sleep(800 * (attempt + 1));
  }
  return '';
}

let cursor = 0;
await Promise.all(Array.from({ length: 5 }, async () => {
  while (true) {
    const i = cursor++;
    if (i >= items.length) return;
    items[i].chinesePrompt = await translate(items[i].prompt);
    console.log(`中文翻译：${i + 1}/${items.length}`);
  }
}));

const csvEscape = value => `"${String(value ?? '').replaceAll('"', '""')}"`;
const columns = ['序号', '图片文件', 'Job ID', '原始提示词', '参数', '完整提示词', '中文翻译', '作品页面', '图片地址'];
const rows = items.map((item, i) => [i + 1, item.filename, item.jobId, item.prompt, item.parameters.join(' '), item.fullPrompt, item.chinesePrompt, item.detailUrl, item.sourceImageUrl]);
const csv = '\uFEFF' + [columns, ...rows].map(row => row.map(csvEscape).join(',')).join('\n');
const markdown = ['# Midjourney Top 图片与提示词', '', `导出数量：${items.length}`, '', ...items.flatMap((item, i) => [
  `## ${i + 1}. ${item.filename || '下载失败'}`, '', `- 原文：${item.prompt || '（未读取到）'}`,
  `- 参数：${item.parameters.join(' ') || '（无）'}`, `- 中文：${item.chinesePrompt || '（未翻译）'}`,
  `- 页面：${item.detailUrl}`, ''
])].join('\n');
await Promise.all([
  writeFile(path.join(ROOT, 'metadata.json'), JSON.stringify(items, null, 2)),
  writeFile(path.join(ROOT, 'prompts.csv'), csv),
  writeFile(path.join(ROOT, 'prompts.md'), markdown)
]);
console.log('修复完成');
