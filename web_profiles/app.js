import {renderVcard, DESIGNS, DESIGN_LAYOUT, CARD_THEMES} from '/vcard.mjs';
import {slugFromPath,safeHttps,safeImageUrl,vcardEscape,fetchProfile,trackScan,ownerLogin,ownerUpdate,ownerUpload} from '/routing.mjs';

const root=document.getElementById('app');
const tools=document.getElementById('tools');
let state={config:null,slug:null,profile:null};

function el(tag,text,cls){const x=document.createElement(tag);if(text!==undefined&&text!==null)x.textContent=text;if(cls)x.className=cls;return x;}
function link(parent,label,url){const safe=safeHttps(url);if(!safe)return;const a=el('a',label,'button');a.href=safe;a.target='_blank';a.rel='noopener noreferrer';parent.append(a);}
function detail(parent,label,value){if(!value)return;const row=el('div',undefined,'detail');row.append(el('span',label),el('strong',value));parent.append(row);}
function status(title,text){root.replaceChildren(el('h1',title),el('p',text));document.title=title;tools.hidden=true;}
function toast(text,bad){const t=el('div',text,'toast'+(bad?' bad':''));document.body.append(t);setTimeout(()=>t.remove(),3200);}

const KIND_NAMES={vcard:'بطاقة اتصال',menu:'القائمة',review:'رأيك يهمنا',equipment:'بطاقة المعدّة',loyalty:'برنامج الولاء'};
// Editable data fields per kind (keys must match the database validator).
const FIELDS={
 vcard:[['full_name','الاسم الكامل'],['job_title','المنصب / المهنة'],['company','الشركة'],['phone','الهاتف'],['whatsapp','واتساب'],['email','البريد'],['website','الموقع (https://…)'],['address','العنوان'],['instagram','Instagram (@اسم أو رابط)'],['tiktok','TikTok'],['facebook','Facebook'],['linkedin','LinkedIn'],['x','X / Twitter'],['youtube','YouTube'],['description','نبذة'],['quote','عبارة مميزة']],
 menu:[['menu_url','رابط القائمة (https://…)'],['description','نبذة']],
 review:[['review_url','رابط التقييم (https://…)'],['description','نبذة']],
 equipment:[['equipment_name','اسم المعدّة'],['serial','الرقم التسلسلي'],['manual_url','رابط الدليل (https://…)'],['description','نبذة']],
 loyalty:[['loyalty_url','رابط برنامج الولاء (https://…)'],['terms','الشروط'],['description','نبذة']],
};

function renderCatalog(parent,items,config){
 if(!Array.isArray(items)||!items.length)return;
 parent.append(el('h2','الكتالوج','section'));
 const grid=el('div',undefined,'catalog');
 for(const item of items){
  const card=el('article',undefined,'item');
  const img=safeImageUrl(item.image_url,config?.supabaseUrl);
  if(img){const i=el('img');i.src=img;i.alt=item.name||'';i.loading='lazy';i.referrerPolicy='no-referrer';i.addEventListener('click',()=>zoom(img));card.append(i);}
  const body=el('div',undefined,'item-body');
  if(item.name)body.append(el('h3',item.name));
  if(item.price)body.append(el('span',item.price,'price'));
  if(item.description)body.append(el('p',item.description));
  card.append(body);grid.append(card);
 }
 parent.append(grid);
}

function zoom(src){
 const d=el('div',undefined,'lightbox');const i=el('img');i.src=src;i.referrerPolicy='no-referrer';d.append(i);
 d.addEventListener('click',()=>d.remove());document.body.append(d);
}

function render(p,config){
 if(!p||!p.business||!p.data){status('الملف غير متاح','قد يكون غير منشور أو تم حذفه.');return;}
 // A loyalty card linked to one of our shops opens the shop page directly.
 if(p.kind==='loyalty'){try{const u=new URL(p.data.loyalty_url);if(u.origin===location.origin&&/^\/c\/[a-z0-9-]+$/.test(u.pathname)){location.replace(u.pathname);return;}}catch{}}
 state.profile=p;
 const b=p.business,d=p.data;
 if(p.kind==='vcard'){
  const tap=renderVcard(root,p,config,toast);
  renderCatalog(root,p.catalog,config);
  tools.hidden=false;
  if(p.editable){let taps=[];tap.addEventListener('click',()=>{const now=Date.now();taps=taps.filter(t=>now-t<1200);taps.push(now);if(taps.length>=3){taps=[];askPin();}});}
  if(p.free)root.append(freeBadge());
  autoEdit();
  return;
 }
 for(const key of ['primary_color','accent_color'])if(/^#[0-9a-f]{6}$/i.test(b[key]??''))document.documentElement.style.setProperty(key==='primary_color'?'--primary':'--accent',b[key]);
 document.title=`${p.title} · ${b.name}`;
 const head=[el('span',KIND_NAMES[p.kind]??'ملف رقمي','pill')];
 const cover=safeImageUrl(p.image_url,config?.supabaseUrl);
 let tapTarget;
 if(cover){
  const img=el('img');img.className='cover';img.src=cover;img.alt=`صورة ${b.name}`;
  img.loading='eager';img.decoding='async';img.referrerPolicy='no-referrer';
  head.push(img);tapTarget=img;
 }else{
  tapTarget=el('div',Array.from(b.name)[0]??'','avatar');head.push(tapTarget);
 }
 head.push(el('div',b.name,'eyebrow'),el('h1',p.title));
 root.replaceChildren(...head);
 if(d.description)root.append(el('p',d.description));
 switch(p.kind){
 case 'vcard':{
  if(d.full_name)root.append(el('h2',d.full_name));detail(root,'الهاتف',d.phone);detail(root,'البريد',d.email);link(root,'زيارة الموقع',d.website);
  if(d.phone&&/^[+0-9 ()-]{3,40}$/.test(d.phone)){const a=el('a','اتصال','button secondary');a.href='tel:'+d.phone.replace(/[^+0-9]/g,'');root.append(a);}
  const download=el('button','حفظ جهة الاتصال','button');download.type='button';
  download.addEventListener('click',()=>{
   const text=['BEGIN:VCARD','VERSION:3.0',`FN:${vcardEscape(d.full_name)}`,`ORG:${vcardEscape(b.name)}`,
    ...(d.phone?[`TEL:${vcardEscape(d.phone)}`]:[]),...(d.email?[`EMAIL:${vcardEscape(d.email)}`]:[]),...(safeHttps(d.website)?[`URL:${vcardEscape(safeHttps(d.website))}`]:[]),'END:VCARD',''].join('\r\n');
   const url=URL.createObjectURL(new Blob([text],{type:'text/vcard;charset=utf-8'}));const a=el('a');a.href=url;a.download=`${p.custom_slug}.vcf`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  });root.append(download);break;}
 case 'menu':link(root,'استعرض القائمة',d.menu_url);break;
 case 'review':root.append(el('p','شارك تجربتك بكل شفافية.'));link(root,'كتابة تقييم',d.review_url);break;
 case 'equipment':detail(root,'المعدّة',d.equipment_name);detail(root,'الرقم التسلسلي',d.serial);link(root,'دليل التشغيل',d.manual_url);break;
 case 'loyalty':link(root,'فتح برنامج الولاء',d.loyalty_url);if(d.terms)root.append(el('p',d.terms,'notice'));break;
 default:break;
 }
 renderCatalog(root,p.catalog,config);
 tools.hidden=false;
 // Hidden owner entry: three quick taps on the photo / initial.
 if(p.editable){
  let taps=[];
  tapTarget.addEventListener('click',()=>{
   const now=Date.now();taps=taps.filter(t=>now-t<1200);taps.push(now);
   if(taps.length>=3){taps=[];askPin();}
  });
 }
}

/* ---------- Save on the phone ---------- */
let installEvent=null;
window.addEventListener('beforeinstallprompt',e=>{e.preventDefault();installEvent=e;});

function isIos(){return /iphone|ipad|ipod/i.test(navigator.userAgent);}
function standalone(){return window.matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;}

async function addToHome(){
 if(standalone()){toast('البطاقة محفوظة على الشاشة الرئيسية بالفعل.');return;}
 if(installEvent){installEvent.prompt();try{await installEvent.userChoice;}catch{}installEvent=null;return;}
 const box=el('div',undefined,'sheet');
 const panel=el('div',undefined,'sheet-panel glass');
 panel.append(el('h2','احفظ البطاقة على شاشتك'));
 if(isIos()){
  panel.append(el('p','1) اضغط زر المشاركة ⬆️ في أسفل Safari.\n2) اختر «إضافة إلى الشاشة الرئيسية».\n3) اضغط «إضافة».'));
 }else{
  panel.append(el('p','1) اضغط على قائمة المتصفح ⋮ في الأعلى.\n2) اختر «إضافة إلى الشاشة الرئيسية» أو «تثبيت التطبيق».\n3) اضغط «إضافة».'));
 }
 const ok=el('button','حسناً','button');ok.type='button';ok.addEventListener('click',()=>box.remove());
 panel.append(ok);box.append(panel);box.addEventListener('click',e=>{if(e.target===box)box.remove();});
 document.body.append(box);
}

function loadImage(src){return new Promise(res=>{const i=new Image();i.crossOrigin='anonymous';i.referrerPolicy='no-referrer';i.onload=()=>res(i);i.onerror=()=>res(null);i.src=src;});}
function roundRect(ctx,x,y,w,h,r){ctx.beginPath();ctx.moveTo(x+r,y);ctx.arcTo(x+w,y,x+w,y+h,r);ctx.arcTo(x+w,y+h,x,y+h,r);ctx.arcTo(x,y+h,x,y,r);ctx.arcTo(x,y,x+w,y,r);ctx.closePath();}

async function saveImage(){
 const p=state.profile;if(!p)return;
 const W=1080,H=640,c=document.createElement('canvas');c.width=W;c.height=H;const ctx=c.getContext('2d');
 const css=getComputedStyle(document.documentElement);
 const primary=css.getPropertyValue('--primary').trim()||'#7367f0',accent=css.getPropertyValue('--accent').trim()||'#2dd4bf';
 const g=ctx.createLinearGradient(0,0,W,H);g.addColorStop(0,'#0b1024');g.addColorStop(1,primary);
 roundRect(ctx,0,0,W,H,48);ctx.fillStyle=g;ctx.fill();
 ctx.direction='rtl';ctx.textAlign='right';
 const cover=safeImageUrl(p.image_url,state.config?.supabaseUrl);
 const img=cover?await loadImage(cover):null;
 if(img){ctx.save();roundRect(ctx,60,60,220,220,40);ctx.clip();const s=Math.max(220/img.width,220/img.height);ctx.drawImage(img,60+(220-img.width*s)/2,60+(220-img.height*s)/2,img.width*s,img.height*s);ctx.restore();}
 else{roundRect(ctx,60,60,220,220,40);ctx.fillStyle='rgba(255,255,255,.12)';ctx.fill();ctx.fillStyle='#fff';ctx.textAlign='center';ctx.font='700 110px system-ui,sans-serif';ctx.fillText(Array.from(p.business.name)[0]??'',170,210);ctx.textAlign='right';}
 ctx.fillStyle=accent;ctx.font='600 34px system-ui,sans-serif';ctx.fillText(p.business.name,W-60,110);
 ctx.fillStyle='#fff';ctx.font='800 64px system-ui,sans-serif';ctx.fillText(p.title.slice(0,24),W-60,190);
 ctx.fillStyle='#dfe3f5';ctx.font='500 38px system-ui,sans-serif';
 let y=300;for(const line of [p.data.full_name,p.data.phone,p.data.email].filter(Boolean)){ctx.fillText(String(line).slice(0,40),W-60,y);y+=56;}
 ctx.fillStyle='rgba(255,255,255,.75)';ctx.font='500 30px system-ui,sans-serif';ctx.textAlign='left';ctx.direction='ltr';
 ctx.fillText(location.host+location.pathname,60,H-60);
 c.toBlob(async blob=>{
  if(!blob){toast('تعذّر إنشاء الصورة',true);return;}
  const file=new File([blob],`${p.custom_slug}.png`,{type:'image/png'});
  if(navigator.canShare&&navigator.canShare({files:[file]})){try{await navigator.share({files:[file],title:p.title});return;}catch{}}
  const url=URL.createObjectURL(blob);const a=el('a');a.href=url;a.download=file.name;a.click();setTimeout(()=>URL.revokeObjectURL(url),2000);
  toast('تم تنزيل صورة البطاقة.');
 },'image/png');
}

/* ---------- Free cards ---------- */
// Free self-made cards carry a small "make yours free" link (how they spread).
function freeBadge(){
 const a=el('a',undefined,'free-badge');a.href='/start';
 const img=el('img');img.src='/logo-256.webp';img.alt='';img.width=22;img.height=22;
 a.append(img,el('span','أنشئ بطاقتك مجاناً مع TapMaroc'));
 return a;
}
// Coming from the account page (tapmaroc.com/start): open the editor directly
// with the one-time edit code it just issued.
async function autoEdit(){
 let code=null;const key='tm_edit_'+state.slug;
 try{code=sessionStorage.getItem(key);sessionStorage.removeItem(key);}catch{}
 if(!code||!/^[0-9]{6,12}$/.test(code))return;
 try{const r=await ownerLogin(state.config,state.slug,code);if(r?.ok)openEditor(r.profile,code);}catch{}
}

/* ---------- Owner editor ---------- */
function modal(){const box=el('div',undefined,'sheet');const panel=el('div',undefined,'sheet-panel glass');box.append(panel);document.body.append(box);return {box,panel};}

function askPin(){
 const {box,panel}=modal();
 panel.append(el('h2','تعديل الملف'),el('p','اكتب الرمز السري الذي أعطاك إياه صاحب الخدمة.'));
 const input=el('input');input.type='password';input.inputMode='numeric';input.autocomplete='one-time-code';input.maxLength=12;input.placeholder='••••••';input.className='field';
 const go=el('button','دخول','button');go.type='button';
 const cancel=el('button','إلغاء','button secondary');cancel.type='button';cancel.addEventListener('click',()=>box.remove());
 const submit=async()=>{
  const pin=input.value.trim();if(!/^[0-9]{6,12}$/.test(pin)){toast('الرمز من 6 إلى 12 رقماً',true);return;}
  go.disabled=true;
  try{
   const r=await ownerLogin(state.config,state.slug,pin);
   if(!r?.ok){toast(r?.error==='Too many attempts, try later'?'محاولات كثيرة، حاول بعد 15 دقيقة.':'الرمز غير صحيح.',true);go.disabled=false;return;}
   box.remove();openEditor(r.profile,pin);
  }catch{toast('تعذّر الاتصال',true);go.disabled=false;}
 };
 go.addEventListener('click',submit);input.addEventListener('keydown',e=>{if(e.key==='Enter')submit();});
 panel.append(input,go,cancel);setTimeout(()=>input.focus(),50);
}

function textField(label,value,multiline){
 const wrap=el('label',undefined,'form-row');wrap.append(el('span',label));
 const input=multiline?el('textarea'):el('input');input.className='field';input.value=value??'';
 wrap.append(input);return {wrap,input};
}

function imagePicker(label,current,onChange){
 const wrap=el('div',undefined,'form-row');wrap.append(el('span',label));
 const preview=el('img');preview.className='thumb';preview.referrerPolicy='no-referrer';
 const set=url=>{if(url){preview.src=url;preview.hidden=false;}else{preview.removeAttribute('src');preview.hidden=true;}};
 set(safeImageUrl(current,state.config?.supabaseUrl));
 const file=el('input');file.type='file';file.accept='image/jpeg,image/png,image/webp';file.hidden=true;
 const pick=el('button','اختيار صورة','button secondary small');pick.type='button';pick.addEventListener('click',()=>file.click());
 const clear=el('button','إزالة','button secondary small');clear.type='button';clear.addEventListener('click',()=>{set(null);onChange({remove:true});});
 file.addEventListener('change',()=>{const f=file.files?.[0];if(!f)return;if(f.size>5*1024*1024){toast('الصورة أكبر من 5 ميغابايت',true);return;}set(URL.createObjectURL(f));onChange({file:f});});
 const row=el('div',undefined,'row');row.append(pick,clear);
 wrap.append(preview,row,file);return wrap;
}

// Ready-made designs (crafts, executives) and simple colours as thumbnails.
// Free (self-made) cards: only a few plain colours; the ready-made designs
// are shown locked as an upgrade. The server enforces the same limits.
function freeDesignChooser(look,allowed){
 const wrap=el('div',undefined,'form-row design-chooser');
 wrap.append(el('span','🎨 لون البطاقة'));
 const row=el('div',undefined,'design-row');const tiles=[];
 const mark=()=>{for(const t of tiles)t.classList.toggle('on',t.dataset.id===look.theme);};
 for(const id of allowed.filter(Boolean)){const t=CARD_THEMES[id];if(!t)continue;
  const b=el('button',undefined,'design-tile');b.type='button';b.dataset.id=id;b.style.setProperty('--t-bg',t.card);b.style.setProperty('--t-ac',t.accent);b.append(el('i','TM'),el('b',''));
  b.addEventListener('click',()=>{look.theme=id;look.layout='';mark();});tiles.push(b);row.append(b);}
 wrap.append(row);
 const pro=el('div',undefined,'design-row locked');
 for(const d of Object.values(DESIGNS).slice(0,8)){
  const b=el('button',undefined,'design-tile');b.type='button';b.style.setProperty('--t-bg',d.palette.surface);b.style.setProperty('--t-ac',d.palette.accent);
  if(d.assets?.cover){const i=el('img');i.src=d.assets.cover;i.alt='';i.loading='lazy';b.append(i);}else b.append(el('i','TM'));
  b.append(el('b','🔒 '+(d.name?.ar??'')));
  b.addEventListener('click',()=>toast('التصاميم الاحترافية وصورة الغلاف متاحة مع بطاقة NFC المدفوعة.'));
  pro.append(b);
 }
 const up=el('a','✨ احصل على التصاميم الاحترافية وبطاقة NFC','button secondary small');
 up.href='https://wa.me/393295586046?text='+encodeURIComponent('مرحباً TapMaroc 👋\nأريد الترقية إلى بطاقة NFC بتصميم احترافي:\n'+location.origin+'/p/'+state.slug);
 up.target='_blank';up.rel='noopener';
 wrap.append(el('small','تصاميم احترافية (مع الباقة المدفوعة)'),pro,up);
 mark();
 return wrap;
}

function designChooser(look){
 const wrap=el('div',undefined,'form-row design-chooser');
 wrap.append(el('span','🎨 تصميم البطاقة'));
 const groups=[['craft','الحرف والمهن'],['executive','مدراء الأعمال']];
 const tiles=[];
 const mark=()=>{for(const t of tiles)t.classList.toggle('on',t.dataset.id===look.theme);};
 const tile=(id,label,bg,accent,img,layout)=>{
  const b=el('button',undefined,'design-tile');b.type='button';b.dataset.id=id;
  b.style.setProperty('--t-bg',bg);b.style.setProperty('--t-ac',accent);
  if(img){const i=el('img');i.src=img;i.alt='';i.loading='lazy';i.decoding='async';b.append(i);}
  else b.append(el('i','TM'));
  b.append(el('b',label));
  b.addEventListener('click',()=>{look.theme=id;look.layout=layout??'';look.colorReset=true;mark();});
  tiles.push(b);return b;
 };
 for(const [g,label] of groups){
  const row=el('div',undefined,'design-row');
  for(const d of Object.values(DESIGNS).filter(x=>x.group===g))row.append(tile(d.id,d.name?.ar??d.id,d.palette.surface,d.palette.accent,d.assets?.cover,DESIGN_LAYOUT[d.layout]));
  if(row.childElementCount)wrap.append(el('small',label),row);
 }
 const simple=el('div',undefined,'design-row');
 for(const [id,t] of Object.entries(CARD_THEMES))simple.append(tile(id,'',t.card,t.accent,null,null));
 wrap.append(el('small','ألوان بسيطة'),simple);
 mark();
 return wrap;
}

function openEditor(profile,pin){
 const {box,panel}=modal();panel.classList.add('editor');
 panel.append(el('h2','تعديل ملفك'));
 const title=textField('العنوان',profile.title);panel.append(title.wrap);
 let cover={keep:true};
 panel.append(imagePicker('الصورة الرئيسية',profile.image_url,v=>{cover=v;}));
 // Business card: its design (ready-made or simple colour) and its cover
 // picture; the owner can change both here.
 let look=null,coverPick={keep:true};
 if(profile.kind==='vcard'){
  look={theme:profile.data?.theme??'',layout:profile.data?.layout??''};
  if(profile.free){panel.append(freeDesignChooser(look,profile.free_themes??['navy','black','ivory','sky']));}
  else{
   panel.append(designChooser(look));
   panel.append(imagePicker('صورة الغلاف (اختياري، بدل صورة التصميم)',profile.data?.cover_url||'',v=>{coverPick=v;}));
  }
 }
 const inputs={};
 for(const [key,label] of FIELDS[profile.kind]??[]){const f=textField(label,profile.data?.[key],key==='description'||key==='terms');inputs[key]=f.input;panel.append(f.wrap);}

 const list=el('div',undefined,'cat-list');
 if(!profile.free){panel.append(el('h3','الكتالوج'));panel.append(list);}
 const items=(Array.isArray(profile.catalog)?profile.catalog:[]).map(x=>({...x}));
 const drawItems=()=>{
  list.replaceChildren();
  items.forEach((item,index)=>{
   const card=el('div',undefined,'cat-edit');
   const n=textField('الاسم',item.name);n.input.addEventListener('input',()=>{item.name=n.input.value;});
   const pr=textField('السعر (اختياري)',item.price);pr.input.addEventListener('input',()=>{item.price=pr.input.value;});
   const ds=textField('الوصف',item.description,true);ds.input.addEventListener('input',()=>{item.description=ds.input.value;});
   const im=imagePicker('صورة العنصر',item.image_url,v=>{item._image=v;});
   const del=el('button','حذف العنصر','button secondary small danger');del.type='button';del.addEventListener('click',()=>{items.splice(index,1);drawItems();});
   card.append(n.wrap,pr.wrap,ds.wrap,im,del);list.append(card);
  });
 };
 drawItems();
 const add=el('button','+ إضافة عنصر','button secondary');add.type='button';
 add.addEventListener('click',()=>{if(items.length>=60){toast('الحد 60 عنصراً',true);return;}items.push({name:'',price:'',description:''});drawItems();});
 if(!profile.free)panel.append(add);

 const save=el('button','حفظ التغييرات','button');save.type='button';
 const close=el('button','إغلاق','button secondary');close.type='button';close.addEventListener('click',()=>box.remove());
 save.addEventListener('click',async()=>{
  save.disabled=true;save.textContent='جارٍ الحفظ…';
  try{
   let imageUrl=null;
   if(cover.file)imageUrl=await ownerUpload(state.config,state.slug,pin,cover.file);
   else if(cover.remove)imageUrl='';
   const catalog=[];
   for(const item of items){
    let url=item.image_url||'';
    if(item._image?.file)url=await ownerUpload(state.config,state.slug,pin,item._image.file);
    else if(item._image?.remove)url='';
    const clean={};
    for(const k of ['name','price','description'])if((item[k]??'').trim())clean[k]=item[k].trim();
    if(url)clean.image_url=url;
    if(clean.name||clean.image_url)catalog.push(clean);
   }
   const data={};
   // Keys not shown in this editor (theme, shape, cover…) are kept as they are.
   for(const [key,v] of Object.entries(profile.data??{}))if(!(key in inputs)&&typeof v==='string'&&v)data[key]=v;
   for(const [key,input] of Object.entries(inputs)){const v=input.value.trim();if(v)data[key]=v;}
   if(look){
    if(look.theme)data.theme=look.theme;
    if(look.layout)data.layout=look.layout;else delete data.layout;
    if(look.colorReset)delete data.color;
    if(coverPick.file)data.cover_url=await ownerUpload(state.config,state.slug,pin,coverPick.file);
    else if(coverPick.remove)delete data.cover_url;
   }
   const r=await ownerUpdate(state.config,state.slug,pin,{title:title.input.value.trim(),data,catalog,imageUrl});
   if(!r?.ok){toast(r?.error==='Too many attempts, try later'?'محاولات كثيرة، حاول لاحقاً.':'تعذّر الحفظ: تأكد من الرمز.',true);return;}
   box.remove();toast('تم الحفظ ✓');
   render(await fetchProfile(state.config,state.slug),state.config);
  }catch(e){
   toast(e?.message==='invalid'?'تأكد من الحقول: الروابط يجب أن تبدأ بـ https://':'تعذّر الحفظ، حاول مرة أخرى.',true);
  }finally{save.disabled=false;save.textContent='حفظ التغييرات';}
 });
 panel.append(save,close);
}

/* ---------- Start ---------- */
async function start(){
 tools.hidden=true;
 document.getElementById('add-home').addEventListener('click',addToHome);
 document.getElementById('save-image').addEventListener('click',saveImage);
 const slug=slugFromPath(location.pathname);
 if(!slug){status('الرابط غير صحيح','استخدم رابط النشاط بصيغة /p/business-name.');return;}
 state.slug=slug;
 let config;
 try{
  const res=await fetch('/config.json',{cache:'no-store'});
  if(!res.ok)throw new Error('config '+res.status);
  config=await res.json();
 }catch{
  status('إعدادات الموقع غير متاحة','لم يُعثر على config.json صالح.');return;
 }
 if(!safeHttps(config?.supabaseUrl)||typeof config?.publishableKey!=='string'||!config.publishableKey){
  status('إعدادات الموقع غير صالحة','يجب أن يحتوي config.json على supabaseUrl (https) وpublishableKey.');return;
 }
 state.config=config;
 try{
  const profile=await fetchProfile(config,slug);
  const source=new URLSearchParams(location.search).get('src');
  if(profile&&profile.business&&profile.data){
   void trackScan(config,slug,source==='qr'||source==='nfc'?source:'link');
  }
  render(profile,config);
 }catch{
  status('تعذّر الاتصال بقاعدة البيانات','تحقق من الإنترنت ثم أعد التحميل.');
 }
}
start();
