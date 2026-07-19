const page=await fetch('https://www.bing.com/translator',{headers:{'User-Agent':'Mozilla/5.0'}});
const cookies=(page.headers.getSetCookie?.()||[]).map(x=>x.split(';')[0]).join('; ');
const html=await page.text();
const m=html.match(/params_AbusePreventionHelper\s*=\s*\[(\d+),"([^"]+)"/);
const ig=html.match(/IG:"([^"]+)"/)?.[1]||'';
const body=new URLSearchParams({fromLang:'en',to:'zh-Hans',text:'beautiful cat',token:m[2],key:m[1],tryFetchingGenderDebiasedTranslations:'true'});
const r=await fetch(`https://www.bing.com/ttranslatev3?isVertical=1&IG=${ig}&IID=translator.5028.1`,{method:'POST',headers:{'User-Agent':'Mozilla/5.0','Content-Type':'application/x-www-form-urlencoded;charset=UTF-8','Referer':'https://www.bing.com/translator','Origin':'https://www.bing.com','Cookie':cookies},body});
console.log(r.status,r.headers.get('content-type'),await r.text());
