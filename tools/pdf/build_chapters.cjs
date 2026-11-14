/* Render complete Markdown lessons with local KaTeX, then add PDF covers. */
const fs = require('fs');
const path = require('path');
const {pathToFileURL} = require('url');
const {spawnSync} = require('child_process');
const {createHash} = require('crypto');
const MarkdownIt = require('markdown-it');
const katex = require('katex');
const ROOT = path.resolve(__dirname,'../..');
const WORK = path.join(ROOT,'work/pdfs');
const OUTPUT = path.join(ROOT,'output/pdf');
const runtime = path.resolve(path.dirname(process.execPath),'../..');
const {chromium} = require(path.join(runtime,'node/node_modules/playwright'));
const chapters = [
  ['00_Fundamentals','波束合成共同基础','传播时间 → 延时对齐 → 相干求和 → PSF 与分辨率'],
  ['01_DAS_Real_UFF','真实 UFF 上的 FI-DAS 与 RTB','聚焦采集 → 几何延时 → DAS → RTB → 实现验证'],
  ['02_CF_GCF','CF / GCF：用空间相干性加权','对齐向量 → 相干因子 → 孔径频谱 → 图像解读'],
  ['03_MVDR','MVDR：从约束到自适应接收权重','估计协方差 → 保留目标模式 → 稳定求解 → 真实实验'],
  ['04_DMAS','DMAS / fDMAS：非线性通道组合','实数 RF → 通道配对 → 频带选择 → 包络与图像'],
  ['05_SLSC','SLSC：把阵元间的相似程度变成图像','延时 RF 窗口 → 空间 lag → 归一化相关 → 像素与显示'],
  ['06_NSI','NSI：先制造中心零点，再用包络相减留下窄响应','中心零点 → 三套权重 → Tx 相干合成 → 包络相减 → 实验'],
  ['07_Benchmark','统一 Benchmark：先问清任务，再判断算法收益','任务 → 共同条件 → 指标定义 → 真实实验 → 收益与代价'],
  ['08_RTB_Comparison','共享 RTB 前端：理解七种组合规则','共同几何 → 七种组合规则 → 输出类型 → 接口与真实对照']
];
const fileNames = [
 '第00章_波束合成共同基础.pdf','第01章_FI-DAS与RTB.pdf',
 '第02章_CF与GCF.pdf','第03章_MVDR.pdf','第04章_DMAS与fDMAS.pdf',
 '第05章_SLSC.pdf','第06章_NSI.pdf','第07章_统一Benchmark.pdf','第08章_七方法RTB对照.pdf'
];
const escape = text => String(text).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const url = file => pathToFileURL(file).href;
const errors = [];

function mathMarkup(tex,displayMode) {
  try {
    return katex.renderToString(tex,{displayMode,throwOnError:true,strict:'ignore',output:'html'});
  } catch(error) {
    errors.push({tex,message:error.message});
    return '<span class="math-error">'+escape(tex)+'</span>';
  }
}

function flowchart(source) {
  // The four source Mermaid diagrams use only labeled nodes and --> edges.
  // Stack them for print readability; the directed graph remains identical.
  const labels = new Map(), edges = [];
  for(const line of source.split(/\r?\n/)) {
    const match = line.trim().match(/^(\w+)(?:\[([^\]]+)\])?\s*-->\s*(\w+)(?:\[([^\]]+)\])?\s*$/);
    if(!match) continue;
    const [,a,la,b,lb] = match;
    if(la) labels.set(a,la); if(lb) labels.set(b,lb);
    edges.push([a,b]);
  }
  if(!edges.length) throw new Error('Unsupported Mermaid diagram');
  const levels = new Map([...labels.keys()].map(k=>[k,0]));
  for(let n=0;n<labels.size;n++) for(const [a,b] of edges) levels.set(b,Math.max(levels.get(b)||0,(levels.get(a)||0)+1));
  const groups = new Map();
  for(const [key,level] of levels) { if(!groups.has(level)) groups.set(level,[]); groups.get(level).push(key); }
  const width = 940, gap = 96, boxHeight = 66, margin = 26;
  const height = (Math.max(...levels.values())+1)*gap+margin*2;
  const positions = new Map();
  for(const [level,keys] of groups) {
    const available = (width-2*margin)/keys.length;
    keys.forEach((key,i)=>positions.set(key,{x:margin+available*(i+0.5),y:margin+level*gap,w:Math.min(570,available-20)}));
  }
  let body = '<defs><marker id="arrow" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto"><path d="M0,0 L9,4.5 L0,9" fill="#217b95"/></marker></defs>';
  for(const [a,b] of edges) {
    const p=positions.get(a),q=positions.get(b);
    body += `<path d="M${p.x},${p.y+boxHeight} L${q.x},${q.y}" stroke="#217b95" stroke-width="2.5" fill="none" marker-end="url(#arrow)"/>`;
  }
  for(const [key,label] of labels) {
    const p=positions.get(key);
    body += `<rect x="${p.x-p.w/2}" y="${p.y}" width="${p.w}" height="${boxHeight}" rx="12" fill="#edf6fa" stroke="#8fb9c8"/>`;
    const chars = [...label], count = Math.max(10,Math.floor(p.w/23));
    const rows=[]; for(let i=0;i<chars.length;i+=count) rows.push(chars.slice(i,i+count).join(''));
    body += `<text x="${p.x}" y="${p.y+boxHeight/2-(rows.length-1)*12}" font-family="Microsoft YaHei" font-size="23" text-anchor="middle" dominant-baseline="middle">`;
    rows.forEach((row,i)=>body+=`<tspan x="${p.x}" dy="${i?25:0}">${escape(row)}</tspan>`);
    body+='</text>';
  }
  return `<figure class="flowchart"><svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${body}</svg><figcaption>算法流程示意（与正文节点和连接关系一致）</figcaption></figure>`;
}

function markdown(chapterDir) {
  const md = new MarkdownIt({html:true,linkify:true,breaks:false});
  md.block.ruler.before('fence','math_display',(state,start,end,silent)=>{
    const line=state.src.slice(state.bMarks[start]+state.tShift[start],state.eMarks[start]).trim();
    if(!line.startsWith('$$')) return false;
    let tex='',last=start;
    if(line.length>4 && line.endsWith('$$')) tex=line.slice(2,-2).trim();
    else {
      const parts=[line.slice(2)];
      for(last=start+1;last<end;last++) {
        const next=state.src.slice(state.bMarks[last],state.eMarks[last]);
        if(next.trim().endsWith('$$')) { parts.push(next.trim().slice(0,-2)); break; }
        parts.push(next);
      }
      tex=parts.join('\n').trim();
    }
    if(silent) return true;
    const token=state.push('math_display','div',0); token.content=tex; token.map=[start,last+1];
    state.line=last+1; return true;
  });
  md.inline.ruler.before('escape','math_inline',(state,silent)=>{
    const pos=state.pos,src=state.src;
    let open,close;
    if(src[pos]==='$' && src[pos+1]!=='$') {open='$';close='$';}
    else if(src.slice(pos,pos+2)==='\\(') {open='\\(';close='\\)';}
    else return false;
    let end=src.indexOf(close,pos+open.length);
    while(end>0 && src[end-1]==='\\' && close==='$') end=src.indexOf(close,end+1);
    if(end<0) return false;
    if(!silent) {const t=state.push('math_inline','span',0); t.content=src.slice(pos+open.length,end);}
    state.pos=end+close.length; return true;
  });
  md.renderer.rules.math_display=(tokens,i)=>`<div class="math-display">${mathMarkup(tokens[i].content,true)}</div>\n`;
  md.renderer.rules.math_inline=(tokens,i)=>mathMarkup(tokens[i].content,false);
  const fence=md.renderer.rules.fence;
  md.renderer.rules.fence=(tokens,i,options,env,self)=>{
    if(tokens[i].info.trim()==='mermaid') return flowchart(tokens[i].content);
    return fence(tokens,i,options,env,self);
  };
  const defaultImage=md.renderer.rules.image;
  md.renderer.rules.image=(tokens,i,options,env,self)=>{
    const source=tokens[i].attrGet('src');
    if(!/^https?:/.test(source)) tokens[i].attrSet('src',url(path.resolve(chapterDir,source)));
    return defaultImage(tokens,i,options,env,self);
  };
  const defaultLink=md.renderer.rules.link_open || ((tokens,i,o,e,self)=>self.renderToken(tokens,i,o));
  md.renderer.rules.link_open=(tokens,i,options,env,self)=>{
    const target=tokens[i].attrGet('href');
    if(target && !/^(https?:|#|mailto:)/.test(target)) {
      const relative=path.relative(ROOT,path.resolve(chapterDir,target.split('#')[0])).split(path.sep).join('/');
      tokens[i].attrSet('href','https://github.com/ajairDD/Ultrasound_Beamforming_Learning/blob/main/'+relative+(target.includes('#')?'#'+target.split('#')[1]:''));
    }
    return defaultLink(tokens,i,options,env,self);
  };
  return md;
}

let katexCss=fs.readFileSync(require.resolve('katex/dist/katex.min.css'),'utf8');
katexCss=katexCss.replace(/url\(([^)]+)\)/g,(_,v)=>`url("${url(path.resolve(path.dirname(require.resolve('katex/dist/katex.min.css')),v.replace(/["']/g,'')))}")`);
const css = `
@page {size:A4;margin:19mm 17mm 19mm;}
*{box-sizing:border-box;} html{background:white;} body{font-family:"Microsoft YaHei",DengXian,sans-serif;color:#203249;font-size:10.3pt;line-height:1.78;margin:0;word-break:normal;overflow-wrap:anywhere;}
h1,h2,h3,h4{color:#123c61;line-height:1.45;break-after:avoid;page-break-after:avoid;font-weight:700;}
h1{font-size:23pt;} h2{font-size:15pt;margin:22pt 0 9pt;border-bottom:1px solid #ccdfe9;padding-bottom:6pt;} h3{font-size:12.3pt;margin:17pt 0 7pt;} h4{font-size:10.8pt;margin:13pt 0 6pt;}
p{margin:6.5pt 0;orphans:3;widows:3;} strong{color:#163b55;} a{color:#1d6e93;text-decoration:none;} ul,ol{padding-left:1.7em;} li{margin:3pt 0;} hr{border:0;border-top:1px solid #d9e5eb;margin:15pt 0;}
blockquote{border-left:3px solid #3194a1;background:#f0f7fa;padding:7pt 12pt;margin:12pt 0;break-inside:avoid;} blockquote p{margin:2pt 0;}
table{border-collapse:collapse;width:100%;font-size:8.5pt;line-height:1.6;margin:12pt 0;table-layout:auto;} thead{display:table-header-group;} th{background:#e9f2f7;color:#123c61;font-weight:700;} th,td{border:0.6px solid #c9dbe5;padding:5pt 6pt;text-align:left;vertical-align:top;} th:first-child,td:first-child{min-width:4em;} tr{break-inside:avoid;page-break-inside:avoid;} tbody tr:nth-child(even){background:#f8fbfc;}
code,pre{font-family:Consolas,"Microsoft YaHei",monospace;font-size:8.8pt;} :not(pre)>code{background:#eef3f6;padding:1px 3px;color:#234e69;} pre{white-space:pre-wrap;overflow-wrap:anywhere;line-height:1.65;padding:10pt;background:#f4f7fa;border:1px solid #d6e2ea;border-radius:5px;break-inside:avoid;}
figure{margin:15pt 0 13pt;break-inside:avoid;page-break-inside:avoid;text-align:center;} figure img{display:block;max-width:100%;max-height:185mm;width:auto;height:auto;margin:0 auto;} figcaption{font-size:9pt;line-height:1.6;color:#46637b;padding-top:6pt;}
.flowchart svg{max-width:100%;max-height:194mm;width:auto;height:auto;} .math-display{margin:13pt 0;break-inside:avoid;text-align:center;} .katex{font-size:1.1em;} .katex-display{margin:0;overflow:visible;} .katex-display>.katex{white-space:nowrap;}
.toc{break-after:page;margin-top:8pt;} .toc h2{border:none;font-size:21pt;} .toc ol{columns:2;column-gap:22pt;list-style:none;padding:0;counter-reset:none;} .toc li{break-inside:avoid;font-size:9pt;line-height:1.6;margin:0 0 7pt;} .toc a{color:#234c68;}
.toc li.toc-group{font-weight:700;margin-top:9pt;} .toc li.toc-subsection{padding-left:10pt;font-size:8.8pt;}
.supplement{break-before:page;} .supplement figure{break-inside:avoid;} details{display:block;} summary{font-weight:700;color:#123c61;margin:10pt 0;} .math-error{color:red;}
/* New lecture chapters: readable Chinese and dedicated large figure pages. */
@page lecture-wide {size:A4 landscape;margin:17mm;}
@page lecture-tall {size:A3 portrait;margin:19mm 17mm;}
.lecture-book{line-break:strict;}
.lecture-book table{font-size:9.2pt;}
.lecture-book figcaption.teaching-caption{text-align:left;font-size:9.7pt;line-height:1.7;}
.lecture-book figure>p.figure-intro,.lecture-book figure>p.figure-followup{text-align:left;font-size:10.5pt;line-height:1.7;margin:0 0 5pt;}
.lecture-book figure>p.figure-followup{margin:5pt 0 0;}
.lecture-book figure>h2,.lecture-book figure>h3,.lecture-book figure>h4{margin:0 0 5pt;padding:0 0 4pt;}
@media print{
 .lecture-book figure.wide-figure{page:lecture-wide;width:263mm;max-width:none;}
 .lecture-book figure.wide-figure img{max-width:263mm;max-height:132mm;}
 .lecture-book figure.tall-figure{page:lecture-tall;width:263mm;max-width:none;}
 .lecture-book figure.tall-figure img{max-width:263mm;max-height:325mm;}
 .lecture-book .wide-table-block{page:lecture-wide;width:263mm;max-width:none;break-inside:avoid;}
 .lecture-book .wide-table-block>h2,.lecture-book .wide-table-block>h3,.lecture-book .wide-table-block>h4{margin:0 0 5pt;padding:0 0 4pt;}
 .lecture-book .wide-table-block>p{font-size:10.5pt;line-height:1.7;margin:0 0 5pt;}
 .lecture-book table.wide-table{width:263mm;max-width:none;font-size:9.8pt;}
}
`;

async function main() {
 fs.mkdirSync(path.join(WORK,'html'),{recursive:true}); fs.mkdirSync(OUTPUT,{recursive:true});
 const args=process.argv.slice(2);
 const flag=args.includes('--chapters')?'--chapters':args.includes('--chapter')?'--chapter':null;
 let selected=null;
 if(flag){
   const specification=args[args.indexOf(flag)+1];
   if(!specification||!/^\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*$/.test(specification))throw new Error('Use --chapter 5 or --chapters 5-8.');
   selected=new Set();
   for(const item of specification.split(',')){
     const [first,last=first]=item.split('-').map(Number);
     if(first<0||last<first||last>=chapters.length)throw new Error('Chapter selection must be within 0-8.');
     for(let n=first;n<=last;n++)selected.add(n);
   }
 }
 const executable=process.env.COURSE_CHROME || ['C:/Program Files/Google/Chrome/Application/chrome.exe','C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe'].find(p=>fs.existsSync(p));
 const browser=await chromium.launch({executablePath:executable,headless:true});
 const records=[];
 try {
  for(let number=0;number<chapters.length;number++) {
   if(selected!==null && !selected.has(number)) continue;
   const [id,title,route]=chapters[number], chapterDir=path.join(ROOT,'chapters',id);
   const rawSource=fs.readFileSync(path.join(chapterDir,'README.md'),'utf8');
   const source=rawSource.replace(/\u2014+/g,'：').replace(/[\u2010-\u2013\u2015]/g,'-');
   const body=markdown(chapterDir).render(source);
   const used=new Set([...source.matchAll(/!\[[^\]]*\]\(([^)]+)\)/g)].map(m=>path.basename(m[1])));
   const extras=fs.readdirSync(path.join(chapterDir,'figures')).filter(f=>f.endsWith('.png')&&!used.has(f)).sort();
   const index=fs.readFileSync(path.join(chapterDir,'figures/README.md'),'utf8');
   const extraHtml=extras.map((name,i)=>{
     const row=index.split(/\r?\n/).find(line=>line.startsWith('|')&&line.includes(']('+name+')'));
     let caption=row?row.split('|').filter(Boolean).at(-1).trim():'与正文配套的数值实验对照';
     caption=caption.replace(/`/g,'').replace(/point-like object/g,'点状目标').replace(/point target/g,'点目标').replace(/point-target/g,'点目标').replace(/full Rx/g,'完整接收孔径').replace(/scanline/g,'扫描线').replace(/conventional/g,'常规 FI').replace(/reference/g,'参考').replace(/self-normalized/g,'各自峰值归一化').replace(/peak/g,'峰值').replace(/Manual/g,'手工实现');
     return `<figure><img src="${url(path.join(chapterDir,'figures',name))}" alt="补充图 ${i+1}"/><figcaption>补充图 ${i+1}｜${escape(caption)}</figcaption></figure>`;
   }).join('\n');
   const html=`<!doctype html><html lang="zh-CN"><head><meta charset="UTF-8"><title>第 ${number} 章 ${escape(title)}</title><style>${katexCss}\n${css}</style></head><body class="${number>=5?'lecture-book':''}"><main>${body}${extras.length?'<section class="supplement"><h2>补充课件图</h2><p>以下图片与本章实验配套，便于课堂选用。保留各图原有的坐标、参数与归一化约定。</p>'+extraHtml+'</section>':''}</main></body></html>`;
   const htmlPath=path.join(WORK,'html',id+'.html'); fs.writeFileSync(htmlPath,html);
   const page=await browser.newPage({viewport:{width:665,height:1000},deviceScaleFactor:1});
   await page.goto(url(htmlPath),{waitUntil:'networkidle'});
   const audit=await page.evaluate(async({widePages})=>{
     await document.fonts.ready;
     document.querySelector('h1')?.remove();
     document.querySelectorAll('details').forEach(d=>d.open=true);
     const groups=[...document.querySelectorAll('main h2')];
     const hasParts=groups.some(h=>/^第[一二三]部分/.test(h.textContent));
     const headings=hasParts?[...document.querySelectorAll('main h2,main h3')]:groups;
     headings.forEach((h,i)=>{if(!h.id)h.id='section-'+i;});
     const toc=document.createElement('section'); toc.className='toc';
     toc.innerHTML='<h2>本章目录</h2><ol></ol>';
     for(const heading of headings) {
       const item=document.createElement('li'),link=document.createElement('a');
       item.className=heading.tagName==='H3'?'toc-subsection':'toc-group';
       link.href='#'+heading.id;link.textContent=heading.textContent;
       item.appendChild(link);toc.querySelector('ol').appendChild(item);
     }
     document.querySelector('main').prepend(toc);
     document.querySelectorAll('p').forEach(p=>{
       if(p.children.length===1&&p.firstElementChild.tagName==='IMG') {
         const img=p.firstElementChild,next=p.nextElementSibling;
         const f=document.createElement('figure'); f.appendChild(img);
         if(widePages && next?.tagName==='P'&&/^图\s*\d/.test(next.textContent.trim())){
           const cap=document.createElement('figcaption');cap.className='teaching-caption';
           cap.innerHTML=next.innerHTML;f.appendChild(cap);next.remove();
         }else if(!(next?.tagName==='P'&&/^图\s*\d/.test(next.textContent.trim()))) {
           const cap=document.createElement('figcaption'); cap.textContent=img.alt; f.appendChild(cap);
         }
         p.replaceWith(f);
       }
     });
     if(widePages){
       document.querySelectorAll('figure').forEach(figure=>{
         const image=figure.querySelector('img');if(!image)return;
         const ratio=image.naturalWidth/image.naturalHeight;
         if(ratio>=1.45)figure.classList.add('wide-figure');
         else if(ratio<1.15&&image.naturalHeight>1400)figure.classList.add('tall-figure');
         if(figure.matches('.wide-figure,.tall-figure')){
           let introductionLength=0;
           while(figure.previousElementSibling?.tagName==='P'){
             const introduction=figure.previousElementSibling,length=introduction.textContent.trim().length;
             if(length>180||introductionLength+length>300)break;
             introductionLength+=length;
             introduction.classList.add('figure-intro');figure.prepend(introduction);
           }
           while(figure.previousElementSibling&&/^H[234]$/.test(figure.previousElementSibling.tagName)){
             figure.prepend(figure.previousElementSibling);
           }
         }
       });
       document.querySelectorAll('figure.wide-figure,figure.tall-figure').forEach(figure=>{
         let followupLength=0;
         while(figure.nextElementSibling?.tagName==='P'){
           const followup=figure.nextElementSibling,length=followup.textContent.trim().length;
           if(length>240||followupLength+length>360)break;
           // Leave an introduction with the code, equation, table or list it introduces.
           if(/[:：]$/.test(followup.textContent.trim())&&followup.nextElementSibling?.matches('pre,.math-display,table,ul,ol'))break;
           followupLength+=length;followup.classList.add('figure-followup');figure.append(followup);
         }
       });
       document.querySelectorAll('table').forEach(table=>{
         if(table.querySelectorAll('thead tr:first-child th').length<6)return;
         table.classList.add('wide-table');
         const block=document.createElement('div');block.className='wide-table-block';
         table.replaceWith(block);block.append(table);
         let introductionLength=0;
         while(block.previousElementSibling?.tagName==='P'){
           const introduction=block.previousElementSibling,length=introduction.textContent.trim().length;
           if(length>180||introductionLength+length>300)break;
           introductionLength+=length;block.prepend(introduction);
         }
         while(block.previousElementSibling&&/^H[234]$/.test(block.previousElementSibling.tagName)){
           block.prepend(block.previousElementSibling);
         }
       });
     }
     document.querySelectorAll('.math-display').forEach(block=>{
       const inner=block.querySelector('.katex-display>.katex'); if(!inner)return;
       const ratio=(block.clientWidth-4)/inner.getBoundingClientRect().width;
       if(ratio<1) inner.style.fontSize=(parseFloat(getComputedStyle(inner).fontSize)*ratio)+'px';
     });
     const failed=[...document.images].filter(i=>!i.complete||!i.naturalWidth).map(i=>i.src);
     const unparsed=[];
     const textNodes=document.createTreeWalker(document.querySelector('main'),NodeFilter.SHOW_TEXT);
     while(textNodes.nextNode()) {
       const node=textNodes.currentNode;
       if(!node.parentElement.closest('pre,code,.katex')&&node.textContent.includes('**'))unparsed.push(node.textContent.slice(0,100));
     }
     const overflow=[...document.querySelectorAll('table,pre,.math-display,figure')].filter(e=>e.scrollWidth>e.clientWidth+5).map(e=>({tag:e.tagName,text:e.textContent.slice(0,90),width:e.scrollWidth,container:e.clientWidth}));
     return {images:document.images.length,failed,overflow,unparsed,headings:headings.map(h=>({text:h.textContent,id:h.id})),math:document.querySelectorAll('.katex').length};
   },{widePages:number>=5});
   const expectedImages=fs.readdirSync(path.join(chapterDir,'figures')).filter(f=>f.endsWith('.png')).length;
   if(audit.failed.length || audit.overflow.length || audit.unparsed.length || audit.images!==expectedImages) throw new Error(JSON.stringify({chapter:id,expectedImages,...audit}));
   // Keep the full figure block within its named page, including its introduction.
   await page.emulateMedia({media:'print'});
   await page.evaluate(()=>{
     const pixelsPerMm=96/25.4;
     document.querySelectorAll('figure.wide-figure,figure.tall-figure').forEach(figure=>{
       const image=figure.querySelector('img'),style=getComputedStyle(figure);
       const pageHeight=(figure.classList.contains('wide-figure')?176:382)*pixelsPerMm;
       const otherHeight=figure.getBoundingClientRect().height-image.getBoundingClientRect().height;
       const margins=parseFloat(style.marginTop)+parseFloat(style.marginBottom);
       const allowedHeight=pageHeight-otherHeight-margins-2*pixelsPerMm;
       if(allowedHeight<=0)throw new Error('Figure text exceeds its page height.');
       image.style.maxHeight=Math.min(parseFloat(getComputedStyle(image).maxHeight),allowedHeight)+'px';
     });
   });
   const bodyPath=path.join(WORK,id+'_body.pdf');
   await page.pdf({path:bodyPath,preferCSSPageSize:true,printBackground:true,tagged:true,outline:true});
   const record={id,number,title,route,file:fileNames[number],body:bodyPath,output:path.join(OUTPUT,fileNames[number]),source:path.join(chapterDir,'README.md'),source_sha256:createHash('sha256').update(rawSource).digest('hex'),extra_images:extras.length,...audit};
   records.push(record); console.log(JSON.stringify({chapter:id,images:audit.images,math:audit.math,pdf:bodyPath}));
   await page.close();
  }
 } finally {await browser.close();}
 if(errors.length) throw new Error(JSON.stringify(errors));
 const manifest=path.join(WORK,'pdf_build_manifest.json'); fs.writeFileSync(manifest,JSON.stringify(records,null,2));
 const python=process.env.COURSE_PYTHON || path.join(runtime,'python/python.exe');
 const result=spawnSync(python,[path.join(__dirname,'finalize_pdfs.py'),manifest],{stdio:'inherit'});
 if(result.status!==0) throw new Error('PDF cover / validation failed');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
