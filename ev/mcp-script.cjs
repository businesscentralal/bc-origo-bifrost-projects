const {execFileSync}=require('child_process');
const CID='233157a0-f5bb-f111-85bd-6045bdfdea7c';
function call(args){let out;try{out=execFileSync('node',['/workspace/tools/origo-call.cjs','invoke_message_type',JSON.stringify({companyId:CID,...args})],{encoding:'utf8',timeout:120000});}catch(e){out=e.stdout||String(e);}
 let t=out;try{t=JSON.parse(out).content[0].text;}catch{} const j=t.split('\n\n--- Message Type Help ---')[0]; try{return JSON.parse(j);}catch{return {raw:t.slice(0,1500)};}}
const types=['Projects.ItemUsage.Post','Projects.WIP.Post','Projects.Quote.Send','Projects.Usage.Link'];
const res=[];let fail=0;
function check(name,cond,detail){res.push({name,pass:!!cond,detail});if(!cond)fail++;}
for(const lcid of [1033,1039]){
 for(const t of types){
  const h=call({type:'Help.Implementation.Get',subject:t,lcid});
  const s=JSON.stringify(h);
  const eff=(s.match(/\\?"effect\\?":\s*\\?"(read|write|irreversible|reversible)/)||[])[1];
  if(t==='Projects.Usage.Link'){check(`${lcid} help ${t} effect write`,eff==='write',eff);continue;}
  check(`${lcid} help ${t} effect irreversible`,eff==='irreversible',eff);
  check(`${lcid} help ${t} changes names unit`,s.includes('expectedCount counts the one project named by projectNo'),'');
  check(`${lcid} help ${t} expectedCount param names unit`,s.includes('Counts the one project named by projectNo'),'');
  const bad=call({type:t,lcid,data:{projectNo:'X42-MCP-NONE',expectedCount:0}});
  check(`${lcid} ${t} expectedCount 0 -> ConfirmationMismatch expected 1`,bad.code==='ConfirmationMismatch'&&String(bad.expected)==='1',{code:bad.code,expected:bad.expected,error:bad.error});
  const miss=call({type:t,lcid,data:{projectNo:'X42-MCP-NONE'}});
  check(`${lcid} ${t} no expectedCount -> ConfirmationRequired expected 1`,miss.code==='ConfirmationRequired'&&String(miss.expected)==='1',{code:miss.code,expected:miss.expected,error:miss.error});
  const ok=call({type:t,lcid,data:{projectNo:'X42-MCP-NONE',expectedCount:1}});
  check(`${lcid} ${t} expectedCount 1 passes gate (type's own refusal, not confirm/unknown)`,ok.status==='Error'&&!['ConfirmationMismatch','ConfirmationRequired','UnknownParameter'].includes(ok.code),{code:ok.code,parameter:ok.parameter,error:ok.error});
 }
 const ul=call({type:'Projects.Usage.Link',lcid,data:{projectNo:'X42-MCP-NONE'}});
 check(`${lcid} Usage.Link without expectedCount -> no confirmation`,ul.code!=='ConfirmationRequired',{status:ul.status,code:ul.code,error:ul.error});
}
console.log(JSON.stringify({at:new Date().toISOString(),fail,total:res.length,res},null,1));
