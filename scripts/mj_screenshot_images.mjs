import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
const ROOT = '/Users/liuzheng/Desktop/Midjourney_Top_Export';
const items = JSON.parse(await readFile(path.join(ROOT, 'metadata.json'), 'utf8'));
const tabs = await (await fetch('http://127.0.0.1:9223/json/list')).json();
const page = tabs.find(t => t.type === 'page' && t.url.includes('midjourney.com'));
if (!page) throw new Error('没有找到 Midjourney 页面');
const ws = new WebSocket(page.webSocketDebuggerUrl);
let nextId = 1; const pending = new Map();
const send = (method, params = {}) => { const id = nextId++; ws.send(JSON.stringify({id, method, params})); return new Promise((resolve,reject)=>pending.set(id,{resolve,reject})); };
ws.onmessage = e => { const m=JSON.parse(e.data); if(!m.id||!pending.has(m.id))return; const p=pending.get(m.id); pending.delete(m.id); m.error?p.reject(new Error(m.error.message)):p.resolve(m.result); };
await new Promise((resolve,reject)=>{ws.onopen=resolve;ws.onerror=reject});
await send('Page.enable'); await send('Runtime.enable');
const sleep = ms => new Promise(r=>setTimeout(r,ms));
const evalValue = async expression => (await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true})).result.value;
for (let i=0;i<items.length;i++) {
  const item=items[i];
  await send('Page.navigate',{url:item.detailUrl});
  let rect=null;
  for(let retry=0;retry<24&&!rect;retry++) {
    await sleep(250);
    rect=await evalValue(`(() => {
      const all=[...document.querySelectorAll('img')].map(el=>({el,r:el.getBoundingClientRect(),src:el.currentSrc||el.src})).filter(x=>x.r.width>180&&x.r.height>180&&x.r.bottom>0&&x.r.top<innerHeight);
      const preferred=all.filter(x=>x.src.includes(${JSON.stringify(item.jobId)}));
      const x=(preferred.length?preferred:all).sort((a,b)=>b.r.width*b.r.height-a.r.width*a.r.height)[0];
      return x?{x:Math.max(0,x.r.x),y:Math.max(0,x.r.y),width:Math.min(innerWidth-Math.max(0,x.r.x),x.r.width),height:Math.min(innerHeight-Math.max(0,x.r.y),x.r.height)}:null;
    })()`);
  }
  if(rect&&rect.width>10&&rect.height>10){
    const shot=await send('Page.captureScreenshot',{format:'png',fromSurface:true,clip:{...rect,scale:1},captureBeyondViewport:false});
    item.filename=`${String(i+1).padStart(3,'0')}_${item.jobId}_${item.imageIndex}.png`;
    delete item.downloadError;
    await writeFile(path.join(ROOT,'images',item.filename),Buffer.from(shot.data,'base64'));
  } else item.downloadError='没有找到可截图的图片区域';
  console.log(`图片截图：${i+1}/${items.length}`);
}
await writeFile(path.join(ROOT,'metadata.json'),JSON.stringify(items,null,2));
ws.close();
