// Local/preview host only. Deploy web_profiles on your own permanent HTTPS domain for NFC cards.
import http from 'node:http';import fs from 'node:fs/promises';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../web_profiles');
const types={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json'};
http.createServer(async(req,res)=>{
 try{
 const pathname=new URL(req.url,'http://preview.local').pathname;
 const relative=pathname.startsWith('/p/')||pathname==='/'?'index.html':decodeURIComponent(pathname).replace(/^\//,'');
 const file=path.resolve(root,relative);
 if(!file.startsWith(root+path.sep)||!Object.hasOwn(types,path.extname(file))){res.writeHead(404);res.end('Not found');return;}
 const data=await fs.readFile(file);res.writeHead(200,{'Content-Type':types[path.extname(file)],'Cache-Control':'no-store','X-Content-Type-Options':'nosniff'});res.end(data);
 }catch{res.writeHead(404);res.end('Not found');}
}).listen(Number(process.env.PORT||8080),'0.0.0.0',()=>console.log('Profile site listening on 0.0.0.0:'+(process.env.PORT||8080)));
