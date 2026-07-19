const tabs = await (await fetch('http://127.0.0.1:9223/json/list')).json();
const page = tabs.find((tab) => tab.type === 'page' && tab.url.includes('midjourney.com/explore'));
if (!page) throw new Error('Midjourney Explore tab not found');

const ws = new WebSocket(page.webSocketDebuggerUrl);
let nextId = 1;
const pending = new Map();
const pages = new Map();

function send(method, params = {}) {
  const id = nextId++;
  ws.send(JSON.stringify({ id, method, params }));
  return new Promise((resolve, reject) => pending.set(id, { resolve, reject }));
}

ws.onmessage = async (event) => {
  const message = JSON.parse(event.data);
  if (message.id) {
    const handler = pending.get(message.id);
    if (!handler) return;
    pending.delete(message.id);
    if (message.error) handler.reject(new Error(message.error.message));
    else handler.resolve(message.result);
    return;
  }
  if (message.method !== 'Network.responseReceived') return;
  const url = message.params.response.url;
  if (!url.includes('/api/explore?')) return;
  const match = url.match(/[?&]page=(\d+)/);
  if (!match) return;
  try {
    const result = await send('Network.getResponseBody', { requestId: message.params.requestId });
    pages.set(Number(match[1]), JSON.parse(result.body));
    console.log(`captured_page=${match[1]}`);
  } catch (error) {
    console.error(`capture_failed page=${match[1]} ${error.message}`);
  }
};

await new Promise((resolve) => { ws.onopen = resolve; });
await send('Network.enable');
await send('Page.enable');
await send('Page.reload', { ignoreCache: true });

for (let i = 0; i < 12; i++) {
  await new Promise((resolve) => setTimeout(resolve, 1500));
  await send('Runtime.evaluate', {
    expression: 'window.scrollTo(0, document.documentElement.scrollHeight)',
    returnByValue: true
  });
  if (pages.size >= 5) break;
}

await new Promise((resolve) => setTimeout(resolve, 2000));
const ordered = [...pages.entries()].sort((a, b) => a[0] - b[0]);
await writeFile('/private/tmp/mj_explore_capture.json', JSON.stringify({ pageCount: ordered.length, pages: ordered }, null, 2));
console.log(`capture_complete pages=${ordered.length} output=/private/tmp/mj_explore_capture.json`);
ws.close();
import { writeFile } from 'node:fs/promises';
