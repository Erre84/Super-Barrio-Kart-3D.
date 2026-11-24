const http=require('node:http'), crypto=require('node:crypto');
const rooms=new Map(), sessions=new Map();
const uid=()=>crypto.randomUUID();
function fail(s,m){throw Object.assign(new Error(m),{status:s});}
function handle(b){const t=Date.now();let r,p,session;const a=b.action;
if(a==='create'||a==='join'){
 if(a==='create'){let code;do{code=crypto.randomBytes(3).toString('hex').toUpperCase()}while(rooms.has(code));r={code,course:['prat','airport','open'].includes(b.course)?b.course:'prat',phase:'lobby',round:1,maxPlayers:30,startsAt:0,players:new Map(),voice:[],signals:[],cursor:0,updated:t};rooms.set(code,r);}else{r=rooms.get(String(b.code||'').trim().toUpperCase());if(!r)fail(404,'Sala no encontrada');if(r.phase!=='lobby'||r.players.size>=30)fail(409,'Sala no disponible');}
 p={id:uid(),token:uid(),name:String(b.name||'Jugador').slice(0,24),profile:String(b.profile||'pepi').slice(0,80),ready:false,state:null,last:t,seq:0};r.players.set(p.id,p);sessions.set(p.id,r);if(!r.hostId)r.hostId=p.id;session={id:p.id,token:p.token};
}else{r=sessions.get(b.id);p=r?.players.get(b.id);if(!p||p.token!==b.token)fail(401,'Sesión caducada');p.last=t;const host=()=>{if(r.hostId!==p.id)fail(403,'Solo el creador');};
 switch(a){case 'prepare':host();if(r.phase!=='lobby'||r.players.size<2)fail(409,'Se necesitan dos jugadores');r.phase='preparing';for(const x of r.players.values())x.ready=false;break;
 case 'ready':p.ready=true;break;
 case 'start':host();if(r.phase!=='preparing'||![...r.players.values()].every(x=>x.ready&&t-x.last<15000))fail(409,'Esperando jugadores');r.phase='racing';r.startsAt=t+3500;break;
 case 'rematch':host();if(r.phase!=='finished')fail(409,'Carrera en curso');r.phase='lobby';r.round++;r.startsAt=0;for(const x of r.players.values()){x.ready=false;x.state=null;}break;
 case 'leave':r.players.delete(p.id);sessions.delete(p.id);if(r.hostId===p.id)r.hostId=r.players.keys().next().value;if(!r.players.size)rooms.delete(r.code);return {serverNow:t,serverReceivedAt:t};
 case 'pulse':if(r.phase==='racing'&&b.state&&Number.isSafeInteger(b.seq)&&b.seq>p.seq){p.seq=b.seq;p.state=b.state;}
 for(const data of (Array.isArray(b.voice)?b.voice:[]).slice(0,6))if(typeof data==='string'&&data.length<=5500)r.voice.push({cursor:++r.cursor,sender:p.id,data,createdAt:t});
 for(const s of (Array.isArray(b.signals)?b.signals:[]).slice(0,32))if(r.players.has(s.to)&&['offer','answer'].includes(s.type)&&typeof s.sdp==='string'&&s.sdp.length<65000)r.signals.push({cursor:++r.cursor,from:p.id,to:s.to,type:s.type,nonce:s.nonce,sdp:s.sdp,createdAt:t});
 if(r.phase==='racing'&&[...r.players.values()].every(x=>x.state?.finished||x.state?.eliminated||t-x.last>30000))r.phase='finished';break;
 default:fail(400,'Acción desconocida');}}
 r.updated=t;r.voice=r.voice.filter(x=>t-x.createdAt<10000).slice(-500);r.signals=r.signals.filter(x=>t-x.createdAt<120000).slice(-1000);
 return {session,room:{code:r.code,hostId:r.hostId,course:r.course,phase:r.phase,round:r.round,maxPlayers:r.maxPlayers,startsAt:r.startsAt},players:[...r.players.values()].map(x=>({id:x.id,name:x.name,profile:x.profile,ready:x.ready,connected:t-x.last<15000,state:x.state})),voice:r.voice.filter(x=>x.cursor>(b.voiceCursor||0)&&x.sender!==p.id),voiceCursor:r.cursor,signals:r.signals.filter(x=>x.cursor>(b.signalCursor||0)&&x.to===p.id),signalCursor:r.cursor,serverReceivedAt:t,serverNow:Date.now()};}
setInterval(()=>{for(const [code,r] of rooms)if(Date.now()-r.updated>3600000){for(const p of r.players.values())sessions.delete(p.id);rooms.delete(code);}},60000).unref();
http.createServer(async(req,res)=>{res.setHeader('Access-Control-Allow-Origin','*');res.setHeader('Access-Control-Allow-Headers','Content-Type');res.setHeader('Access-Control-Allow-Methods','GET,POST,OPTIONS');res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');if(req.method==='OPTIONS'){res.writeHead(204);return res.end();}try{if(req.method==='GET'&&['/','/health'].includes(req.url))return res.end(JSON.stringify({ok:true,service:'SBK Nueva Era test'}));if(req.method!=='POST'||req.url!=='/api/rooms')fail(404,'Ruta desconocida');let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>2300000)fail(413,'Petición demasiado grande');}res.end(JSON.stringify(handle(JSON.parse(raw))));}catch(e){res.statusCode=e.status||400;res.end(JSON.stringify({error:e.message}));}}).listen(process.env.PORT||3000,'0.0.0.0');
