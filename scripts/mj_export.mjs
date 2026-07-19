import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';

const DEBUG_URL = 'http://127.0.0.1:9223';
const EXPLORE_URL = 'https://www.midjourney.com/explore?tab=top';
const OUTPUT_DIR = '/Users/liuzheng/Desktop/Midjourney_Top_Export';
const IMAGE_DIR = path.join(OUTPUT_DIR, 'images');
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const tabs = await (await fetch(`${DEBUG_URL}/json/list`)).json();
const page = tabs.find((tab) => tab.type === 'page' && tab.url.includes('midjourney.com'));
if (!page) throw new Error('没有找到已打开的 Midjourney 页面');

const ws = new WebSocket(page.webSocketDebuggerUrl);
let nextId = 1;
const pending = new Map();
function send(method, params = {}) {
  const id = nextId++;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}
ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  if (!message.id) return;
  const handler = pending.get(message.id);
  if (!handler) return;
  pending.delete(message.id);
  if (message.error) handler.reject(new Error(message.error.message));
  else handler.resolve(message.result);
};
await new Promise((resolve, reject) => {
  ws.onopen = resolve;
  ws.onerror = reject;
});
await send('Page.enable');
await send('Runtime.enable');

async function evaluate(expression) {
  const result = await send('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true });
  if (result.exceptionDetails) throw new Error(result.exceptionDetails.text || '页面脚本执行失败');
  return result.result.value;
}

async function navigate(url) {
  await send('Page.navigate', { url });
  for (let i = 0; i < 40; i++) {
    await sleep(250);
    const state = await evaluate('document.readyState');
    if (state === 'complete' || state === 'interactive') return;
  }
}

await navigate(EXPLORE_URL);
await sleep(2500);
await evaluate(`window.__mjItems = Object.create(null)`);

let previousCount = 0;
let unchanged = 0;
for (let round = 0; round < 80; round++) {
  const status = await evaluate(`(() => {
    for (const anchor of document.querySelectorAll('a[href^="/jobs/"]')) {
      const match = anchor.getAttribute('href')?.match(/^\\/jobs\\/([^?]+)\\?index=(\\d+)/);
      if (!match) continue;
      const bg = getComputedStyle(anchor).backgroundImage || anchor.style.backgroundImage || '';
      const urls = [...bg.matchAll(/https:\\/\\/cdn\\.midjourney\\.com\\/[^"') ]+/g)].map(x => x[0]);
      const imageUrl = urls.find(x => /_640_\\d+\\.webp/.test(x)) || urls[0] || '';
      const key = match[1] + ':' + match[2];
      window.__mjItems[key] = { jobId: match[1], imageIndex: Number(match[2]), imageUrl, detailUrl: new URL(anchor.href, location.origin).href };
    }
    const candidates = [document.scrollingElement, ...document.querySelectorAll('*')].filter(Boolean);
    let scroller = document.scrollingElement;
    for (const el of candidates) {
      if ((el.scrollHeight - el.clientHeight) > (scroller.scrollHeight - scroller.clientHeight)) scroller = el;
    }
    const before = scroller.scrollTop;
    scroller.scrollTop = Math.min(scroller.scrollHeight, scroller.scrollTop + Math.max(innerHeight * 1.6, 900));
    return { count: Object.keys(window.__mjItems).length, before, after: scroller.scrollTop, height: scroller.scrollHeight };
  })()`);
  console.log(`扫描页面：${status.count} 张`);
  if (status.count === previousCount && status.after === status.before) unchanged++;
  else unchanged = 0;
  previousCount = status.count;
  if (unchanged >= 5) break;
  await sleep(800);
}

const items = await evaluate('Object.values(window.__mjItems)');
if (!items.length) throw new Error('页面上没有读取到图片，请确认安全验证已经通过并显示了作品');
console.log(`共发现 ${items.length} 张图片，开始读取提示词`);

for (let i = 0; i < items.length; i++) {
  const item = items[i];
  await navigate(item.detailUrl);
  let detail = null;
  for (let retry = 0; retry < 30 && !detail; retry++) {
    await sleep(250);
    detail = await evaluate(`(() => {
      const root = document.querySelector('#lightboxPrompt');
      if (!root) return null;
      const prompt = root.querySelector('.notranslate')?.innerText.trim() || '';
      const parameters = [...root.querySelectorAll('button')].map(button =>
        [...button.querySelectorAll('span')].map(span => span.textContent.trim()).find(text => text.startsWith('--'))
      ).filter(Boolean);
      return { prompt, parameters, fullPrompt: [prompt, ...parameters].filter(Boolean).join(' ') };
    })()`);
  }
  Object.assign(item, detail || { prompt: '', parameters: [], fullPrompt: '' });
  console.log(`提示词：${i + 1}/${items.length}`);
}

await mkdir(IMAGE_DIR, { recursive: true });

async function translate(text) {
  if (!text || !/[A-Za-z]/.test(text)) return text;
  try {
    const url = new URL('https://translate.googleapis.com/translate_a/single');
    url.search = new URLSearchParams({ client: 'gtx', sl: 'auto', tl: 'zh-CN', dt: 't', q: text });
    const response = await fetch(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    if (!response.ok) return '';
    const data = await response.json();
    return (data[0] || []).map((part) => part[0] || '').join('');
  } catch {
    return '';
  }
}

function extension(contentType, url) {
  if (contentType.includes('png')) return 'png';
  if (contentType.includes('jpeg')) return 'jpg';
  if (contentType.includes('webp')) return 'webp';
  return new URL(url).pathname.split('.').pop() || 'webp';
}

async function processItem(item, i) {
  item.chinesePrompt = await translate(item.prompt);
  const candidates = [
    `https://cdn.midjourney.com/${item.jobId}/0_${item.imageIndex}.png`,
    item.imageUrl?.replace('_640_', '_2048_'),
    item.imageUrl
  ].filter(Boolean);
  let response;
  let selectedUrl;
  for (const url of [...new Set(candidates)]) {
    try {
      const candidate = await fetch(url);
      if (candidate.ok && candidate.headers.get('content-type')?.startsWith('image/')) {
        response = candidate;
        selectedUrl = url;
        break;
      }
    } catch {}
  }
  if (response) {
    const ext = extension(response.headers.get('content-type') || '', selectedUrl);
    item.filename = `${String(i + 1).padStart(3, '0')}_${item.jobId}_${item.imageIndex}.${ext}`;
    await writeFile(path.join(IMAGE_DIR, item.filename), Buffer.from(await response.arrayBuffer()));
  } else {
    item.filename = '';
    item.downloadError = '图片下载失败';
  }
  item.sourceImageUrl = selectedUrl || item.imageUrl;
  console.log(`下载与翻译：${i + 1}/${items.length}`);
}

const DOWNLOAD_CONCURRENCY = 8;
let workIndex = 0;
await Promise.all(Array.from({ length: DOWNLOAD_CONCURRENCY }, async () => {
  while (true) {
    const i = workIndex++;
    if (i >= items.length) return;
    await processItem(items[i], i);
  }
}));

const csvEscape = (value) => `"${String(value ?? '').replaceAll('"', '""')}"`;
const columns = ['序号', '图片文件', 'Job ID', '原始提示词', '参数', '完整提示词', '中文翻译', '作品页面', '图片地址'];
const rows = items.map((item, i) => [i + 1, item.filename, item.jobId, item.prompt, item.parameters.join(' '), item.fullPrompt, item.chinesePrompt, item.detailUrl, item.sourceImageUrl]);
const csv = '\uFEFF' + [columns, ...rows].map(row => row.map(csvEscape).join(',')).join('\n');
const markdown = ['# Midjourney Top 图片与提示词', '', `导出数量：${items.length}`, '', ...items.flatMap((item, i) => [
  `## ${i + 1}. ${item.filename || '下载失败'}`,
  '',
  `- 原文：${item.prompt || '（未读取到）'}`,
  `- 参数：${item.parameters.join(' ') || '（无）'}`,
  `- 中文：${item.chinesePrompt || '（未翻译）'}`,
  `- 页面：${item.detailUrl}`,
  ''
])].join('\n');

await Promise.all([
  writeFile(path.join(OUTPUT_DIR, 'prompts.csv'), csv),
  writeFile(path.join(OUTPUT_DIR, 'prompts.md'), markdown),
  writeFile(path.join(OUTPUT_DIR, 'metadata.json'), JSON.stringify(items, null, 2))
]);
console.log(`导出完成：${OUTPUT_DIR}`);
ws.close();
