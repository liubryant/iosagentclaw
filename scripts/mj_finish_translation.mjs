import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
const ROOT='/Users/liuzheng/Desktop/Midjourney_Top_Export';
const items=JSON.parse(await readFile(path.join(ROOT,'metadata.json'),'utf8'));
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const pageResponse=await fetch('https://www.bing.com/translator',{headers:{'User-Agent':'Mozilla/5.0'}});
const html=await pageResponse.text();
const tokenMatch=html.match(/params_AbusePreventionHelper\s*=\s*\[(\d+),"([^"]+)"/);
const ig=html.match(/IG:"([^"]+)"/)?.[1]||'';
if(!tokenMatch) throw new Error('无法获取 Bing 翻译临时令牌');
const [,key,token]=tokenMatch;
async function translate(text){
  if(!text||!/[A-Za-z]/.test(text))return text;
  for(let attempt=0;attempt<3;attempt++){
    try{
      const body=new URLSearchParams({fromLang:'auto-detect',to:'zh-Hans',text:text.slice(0,950),token,key});
      const r=await fetch(`https://www.bing.com/ttranslatev3?isVertical=1&IG=${ig}&IID=translator.5028.1`,{
        method:'POST',headers:{'User-Agent':'Mozilla/5.0','Content-Type':'application/x-www-form-urlencoded','Content-Length':String(Buffer.byteLength(body.toString()))},body:body.toString()
      });
      const data=await r.json();
      const result=data?.[0]?.translations?.[0]?.text;
      if(result)return result;
    }catch{}
    await sleep(600*(attempt+1));
  }
  return '';
}
let cursor=0;
await Promise.all(Array.from({length:4},async()=>{while(true){const i=cursor++;if(i>=items.length)return;if(!items[i].chinesePrompt||items[i].chinesePrompt.startsWith('MYMEMORY WARNING'))items[i].chinesePrompt=await translate(items[i].prompt);console.log(`翻译补齐：${i+1}/${items.length}`)}}));
const esc=v=>`"${String(v??'').replaceAll('"','""')}"`;
const columns=['序号','图片文件','Job ID','原始提示词','参数','完整提示词','中文翻译','作品页面','图片地址'];
const rows=items.map((x,i)=>[i+1,x.filename,x.jobId,x.prompt,x.parameters.join(' '),x.fullPrompt,x.chinesePrompt,x.detailUrl,x.sourceImageUrl]);
const csv='\uFEFF'+[columns,...rows].map(r=>r.map(esc).join(',')).join('\n');
const md=['# Midjourney Top 图片与提示词','',`导出数量：${items.length}`,'',...items.flatMap((x,i)=>[`## ${i+1}. ${x.filename||'图片缺失'}`,'',`- 原文：${x.prompt||'（未读取到）'}`,`- 参数：${x.parameters.join(' ')||'（无）'}`,`- 中文：${x.chinesePrompt||'（未翻译）'}`,`- 页面：${x.detailUrl}`,''])].join('\n');
await Promise.all([writeFile(path.join(ROOT,'metadata.json'),JSON.stringify(items,null,2)),writeFile(path.join(ROOT,'prompts.csv'),csv),writeFile(path.join(ROOT,'prompts.md'),md)]);
console.log('翻译和清单更新完成');
