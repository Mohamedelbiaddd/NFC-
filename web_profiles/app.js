import {slugFromPath,safeHttps,vcardEscape,fetchProfile} from '/routing.mjs';
const root=document.getElementById('app');
function el(tag,text,cls){const x=document.createElement(tag);if(text!==undefined)x.textContent=text;if(cls)x.className=cls;return x;}
function link(label,url){const safe=safeHttps(url);if(!safe)return;const a=el('a',label,'button');a.href=safe;a.target='_blank';a.rel='noopener noreferrer';root.append(a);}
function detail(label,value){if(!value)return;const row=el('div',undefined,'detail');row.append(el('span',label),el('strong',value));root.append(row);}
function status(title,text){root.replaceChildren(el('h1',title),el('p',text));document.title=title;}
function render(p){
 if(!p||!p.business||!p.data){status('الملف غير متاح','قد يكون غير منشور أو تم حذفه.');return;}
 const b=p.business,d=p.data;
 for(const key of ['primary_color','accent_color'])if(/^#[0-9a-f]{6}$/i.test(b[key]??''))document.documentElement.style.setProperty(key==='primary_color'?'--primary':'--accent',b[key]);
 document.title=`${p.title} · ${b.name}`;
 const names={vcard:'بطاقة اتصال',menu:'القائمة',review:'رأيك يهمنا',equipment:'بطاقة المعدّة',loyalty:'برنامج الولاء'};
 root.replaceChildren(el('span',names[p.kind]??'ملف رقمي','pill'),el('div',Array.from(b.name)[0]??'','avatar'),el('div',b.name,'eyebrow'),el('h1',p.title));
 if(d.description)root.append(el('p',d.description));
 switch(p.kind){
 case 'vcard':{
 root.append(el('h2',d.full_name));detail('الهاتف',d.phone);detail('البريد',d.email);link('زيارة الموقع',d.website);
 if(d.phone&&/^[+0-9 ()-]{3,40}$/.test(d.phone)){const a=el('a','اتصال','button secondary');a.href='tel:'+d.phone.replace(/[^+0-9]/g,'');root.append(a);}
 const download=el('button','حفظ جهة الاتصال','button');download.type='button';
 download.addEventListener('click',()=>{
 const text=['BEGIN:VCARD','VERSION:3.0',`FN:${vcardEscape(d.full_name)}`,`ORG:${vcardEscape(b.name)}`,
 ...(d.phone?[`TEL:${vcardEscape(d.phone)}`]:[]),...(d.email?[`EMAIL:${vcardEscape(d.email)}`]:[]),...(safeHttps(d.website)?[`URL:${vcardEscape(safeHttps(d.website))}`]:[]),'END:VCARD',''].join('\r\n');
 const url=URL.createObjectURL(new Blob([text],{type:'text/vcard;charset=utf-8'}));const a=el('a');a.href=url;a.download=`${p.custom_slug}.vcf`;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
 });root.append(download);break;}
 case 'menu':link('استعرض القائمة',d.menu_url);break;
 case 'review':root.append(el('p','شارك تجربتك بكل شفافية.'));link('كتابة تقييم',d.review_url);break;
 case 'equipment':detail('المعدّة',d.equipment_name);detail('الرقم التسلسلي',d.serial);link('دليل التشغيل',d.manual_url);break;
 case 'loyalty':link('فتح برنامج الولاء',d.loyalty_url);if(d.terms)root.append(el('p',d.terms,'notice'));break;
 default:status('قالب غير مدعوم','تواصل مع صاحب النشاط.');
 }
}
async function start(){
 const slug=slugFromPath(location.pathname);
 if(!slug){status('الرابط غير صحيح','استخدم رابط النشاط بصيغة /p/business-name.');return;}
 try{const res=await fetch('/config.json',{cache:'no-store'});if(!res.ok)throw new Error('Configuration');const config=await res.json();render(await fetchProfile(config,slug));}
 catch{status('تعذّر تحميل الملف','تحقق من الاتصال ثم أعد تحميل الصفحة.');}
}
start();
