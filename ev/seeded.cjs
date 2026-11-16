const {execFileSync}=require('child_process');
const CID='233157a0-f5bb-f111-85bd-6045bdfdea7c';
function raw(tool,args){let out;try{out=execFileSync('node',['/workspace/tools/origo-call.cjs',tool,JSON.stringify({companyId:CID,...args})],{encoding:'utf8',timeout:120000});}catch(e){out=e.stdout||String(e);}let t=out;try{t=JSON.parse(out).content[0].text;}catch{}return t;}
function call(a){const t=raw('invoke_message_type',a).split('\n\n--- Message Type Help ---')[0];try{return JSON.parse(t);}catch{return {raw:t.slice(0,800)};}}
function api(a){const t=raw('bc_api_request',a);try{return JSON.parse(t);}catch{return {raw:t.slice(0,800)};}}
const P='X42MCP'+Date.now().toString().slice(-6);
const res=[];let fail=0;const chk=(n,c,d)=>{res.push({name:n,pass:!!c,detail:d});if(!c)fail++;};
const cr=api({method:'POST',entity:'projects',body:{number:P,displayName:'X Projects 42 MCP seed'}});
const row=cr.body||cr.row||(cr.rows&&cr.rows[0])||cr;
const id=row.id; chk('seed project via REST',!!id,{number:P,statusCode:cr.statusCode,id});
for(const lcid of [1033,1039]){
 for(const t of ['Projects.ItemUsage.Post','Projects.WIP.Post','Projects.Quote.Send']){
  const m=call({type:t,lcid,data:{projectNo:P,expectedCount:0}});
  chk(`${lcid} ${t} seeded project, expectedCount 0 -> ConfirmationMismatch expected 1 naming the project`,m.code==='ConfirmationMismatch'&&String(m.expected)==='1'&&String(m.error).includes(P),{code:m.code,expected:m.expected,error:m.error});
 }
 const iu=call({type:'Projects.ItemUsage.Post',lcid,data:{projectNo:P,taskNo:'X42-NOTASK',lines:[{itemNo:'X42-NOITEM',quantity:1}],expectedCount:1}});
 chk(`${lcid} ItemUsage.Post seeded project, expectedCount 1 -> gate passed, own refusal, nothing posted`,iu.status==='Error'&&!['ConfirmationMismatch','ConfirmationRequired','UnknownParameter'].includes(iu.code),{code:iu.code,parameter:iu.parameter,error:iu.error});
 const qs=call({type:'Projects.Quote.Send',lcid,data:{projectNo:P,expectedCount:1}});
 chk(`${lcid} Quote.Send seeded non-Quote project, expectedCount 1 -> gate passed, PreconditionFailed, nothing sent`,qs.code==='PreconditionFailed',{code:qs.code,error:qs.error});
 const ul=call({type:'Projects.Usage.Link',lcid,data:{projectNo:P}});
 chk(`${lcid} Usage.Link seeded project, no expectedCount -> not gated`,ul.code!=='ConfirmationRequired'&&ul.code!=='ConfirmationMismatch',{status:ul.status,code:ul.code,error:ul.error});
}
const le=api({entity:'projects',filter:`number eq '${P}'`});
const del=api({method:'DELETE',entity:'projects',id});
chk('cleanup: project deleted',del.statusCode===204||del.ok===true,{statusCode:del.statusCode});
const after=api({entity:'projects',filter:`number eq '${P}'`});
chk('cleanup: project gone',after.rowCount===0,{rowCount:after.rowCount});
const jle=raw('get_record_count',{tableName:'Job Ledger Entry',filter:`WHERE(Job No.=FILTER(${P}))`});
console.log(JSON.stringify({at:new Date().toISOString(),project:P,fail,total:res.length,res,jobLedgerCountForSeed:jle.slice(0,300)},null,1));
