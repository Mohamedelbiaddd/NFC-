export const reserved = new Set(['admin','api','assets','auth','login','logout','settings','www','new']);
export function validSlug(s) {return typeof s==='string'&&s.length>=3&&s.length<=63&&/^[a-z0-9]+(-[a-z0-9]+)*$/.test(s)&&!reserved.has(s);}
export function slugFromPath(path) {
 const match=/^\/p\/([^/]+)\/?$/.exec(path);
 if(!match)return null;
 // Reject encoded slashes, double decoding, upper case aliases and traversal.
 try{const slug=decodeURIComponent(match[1]);return validSlug(slug)&&encodeURIComponent(slug)===match[1]?slug:null;}catch{return null;}
}
export function safeHttps(value){try{const u=new URL(value);return u.protocol==='https:'&&!u.username&&!u.password?u.href:null;}catch{return null;}}
// Only objects served from the project's public Storage endpoint may be used
// as a profile image, so a crafted image_url cannot leak visitors' requests to
// a third party host.
export function safeImageUrl(value, supabaseUrl) {
 const href=safeHttps(value);
 if(!href)return null;
 try{
  const url=new URL(href), base=new URL(supabaseUrl);
  if(url.origin!==base.origin)return null;
  if(!url.pathname.startsWith('/storage/v1/object/public/'))return null;
  return url.href;
 }catch{return null;}
}
export function vcardEscape(value){return String(value??'').replace(/\\/g,'\\\\').replace(/\r\n|\r|\n/g,'\\n').replace(/;/g,'\\;').replace(/,/g,'\\,');}
export async function fetchProfile(config,slug,fetcher=fetch){
 if(!validSlug(slug))throw new Error('Invalid slug');
 const response=await fetcher(`${config.supabaseUrl}/rest/v1/rpc/nfc_public_profile_by_slug`,{
 method:'POST',headers:{'Content-Type':'application/json',apikey:config.publishableKey},body:JSON.stringify({slug}),cache:'no-store'});
 if(!response.ok)throw new Error('Profile lookup failed');
 return response.json();
}

// Fire-and-forget scan counter. The database only accepts published slugs and
// de-duplicates rapid repeats, so this can never be used to probe profiles.
export async function trackScan(config,slug,source='link',fetcher=fetch){
 if(!config?.supabaseUrl||!config?.publishableKey)return;
 if(!validSlug(slug))return;
 try{
  await fetcher(`${config.supabaseUrl}/rest/v1/rpc/nfc_track_scan`,{
   method:'POST',
   headers:{'Content-Type':'application/json',apikey:config.publishableKey},
   body:JSON.stringify({target_slug:slug,scan_source:source,agent:String(globalThis.navigator?.userAgent??'').slice(0,300)}),
   cache:'no-store',keepalive:true,
  });
 }catch{/* counting must never break the page */}
}
