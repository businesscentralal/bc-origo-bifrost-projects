'use strict';
const fs=require('node:fs');
const {execFileSync}=require('node:child_process');
const {Client}=require('/usr/local/lib/node_modules/origo-bc-mcp-server/node_modules/@modelcontextprotocol/sdk/dist/cjs/client/index.js');
const {StdioClientTransport}=require('/usr/local/lib/node_modules/origo-bc-mcp-server/node_modules/@modelcontextprotocol/sdk/dist/cjs/client/stdio.js');
const dir=__dirname;
const output={sha:execFileSync('git',['-C','/workspace/private/projects16-worker4','rev-parse','HEAD'],{encoding:'utf8'}).trim(),tenant:'w129-14',startedAt:new Date().toISOString(),rows:[],cleanup:[],fixtures:[],help:{}};
const client=new Client({name:'projects16-self-seeded-verification',version:'1'});
let lcid=1033;
const save=()=>fs.writeFileSync(dir+'/mcp-results.json',JSON.stringify(output,null,2));
async function invoke(type,data={},subject){
 const r=await client.callTool({name:'invoke_message_type',arguments:{type,data,lcid,...(subject?{subject}:{})}},undefined,{timeout:120000});
 const t=r.content.filter(x=>x.type==='text').map(x=>x.text).join('\n');
 let v;try{v=JSON.parse(t.split('\n\n---')[0]);}catch{throw Error(type+' invalid response: '+t.slice(0,200));}
 return v;
}
function assert(ok,message){if(!ok)throw Error(message);}
function success(r){assert(r.status==='Success','Expected success: '+JSON.stringify(r));return r;}
function refusal(r,code){assert(r.status==='Error'&&r.code===code,'Expected '+code+': '+JSON.stringify(r));assert(typeof r.nextStep==='string'&&r.nextStep.length>0,'Missing nextStep: '+JSON.stringify(r));return r;}
async function check(name,fn){const row={lcid,name,pass:false};output.rows.push(row);try{row.result=await fn();row.pass=true;}catch(e){row.error=e.message;throw e;}finally{save();}}
async function seed(tableName,fields){return success(await invoke('Test.Records.Set',{tableName,records:[{fields}]}));}
async function clean(tableName,field,code){const r=success(await invoke('Test.Records.Delete',{tableName,tableView:'WHERE('+field+'=CONST('+code+'))'}));output.cleanup.push({tableName,field,code,result:r});save();}
(async()=>{
 await client.connect(new StdioClientTransport({command:'node',args:['/workspace/tools/origo-mcp.cjs'],stderr:'pipe'}));
 try{
 for(lcid of [1033,1039]){
  const suffix=lcid===1033?'E':'I';
  const prefix='X16M'+suffix+Date.now().toString().slice(-8);
  const code=prefix+'C', system=prefix+'S', posted=prefix+'P', calc=prefix+'A';
  const codes=[code,system,posted,calc];
  output.fixtures.push({lcid,codes});save();
  try{
   await check('Set creates custom method',async()=>success(await invoke('Projects.WIPMethod.Set',{code,description:'Owned MCP WIP method'})));
   await check('Set updates all native settings',async()=>success(await invoke('Projects.WIPMethod.Set',{code,description:'Owned MCP updated',recognizedCosts:'Usage (Total Cost)',recognizedSales:'Contract (Invoiced Price)',wipCost:false,wipSales:false,valid:false})));
   await check('Get returns stable recognized settings and every flag',async()=>{
    const r=success(await invoke('Projects.WIPMethod.Get',{code}));assert(r.methods.length===1,'Exact lookup scope');const m=r.methods[0];assert(m.recognizedCosts==='Usage (Total Cost)'&&m.recognizedSales==='Contract (Invoiced Price)'&&!m.wipCost&&!m.wipSales&&!m.valid&&!m.systemDefined&&m.description==='Owned MCP updated','Native settings mismatch');return r;
   });
   await check('Get without code lists owned method',async()=>{const r=success(await invoke('Projects.WIPMethod.Get',{}));assert(r.methods.some(x=>x.code===code),'Owned method absent');return {status:r.status,count:r.methods.length,ownedPresent:true};});
   await check('Set preserves omitted fields',async()=>{success(await invoke('Projects.WIPMethod.Set',{code,description:'Partial update'}));const r=success(await invoke('Projects.WIPMethod.Get',{code}));assert(!r.methods[0].wipCost&&!r.methods[0].wipSales&&!r.methods[0].valid,'Omitted fields overwritten');return r;});
   await check('Native invalid change rolls back all fields',async()=>{const r=refusal(await invoke('Projects.WIPMethod.Set',{code,description:'Must rollback',recognizedCosts:'At Completion',wipCost:false}),'BusinessCentralError');const read=success(await invoke('Projects.WIPMethod.Get',{code}));assert(read.methods[0].description==='Partial update'&&read.methods[0].recognizedCosts==='Usage (Total Cost)','Rollback failed');return r;});
   for(const [name,data,expected] of [
    ['missing code',{},'MissingParameter'],['empty code',{code:''},'MissingParameter'],['blank code',{code:'   '},'MissingParameter'],
    ['null code',{code:null},'InvalidParameterFormat'],['numeric code',{code:7},'InvalidParameterFormat'],['overlong code',{code:'123456789012345678901'},'InvalidParameterFormat'],
    ['boolean string',{code,wipCost:'false'},'InvalidParameterFormat'],['unknown cost enum',{code,recognizedCosts:'INVALID'},'InvalidParameterFormat'],
    ['object enum',{code,recognizedSales:{}},'InvalidParameterFormat'],['null flag',{code,valid:null},'InvalidParameterFormat'],
    ['overlong description',{code,description:'x'.repeat(101)},'InvalidParameterFormat'],['protected flag input',{code,systemDefined:false},'UnknownParameter']
   ])await check('Set rejects '+name,async()=>refusal(await invoke('Projects.WIPMethod.Set',data),expected));
   await check('Get unknown code is actionable',async()=>refusal(await invoke('Projects.WIPMethod.Get',{code:prefix+'Z'}),'RecordNotFound'));
   await check('Get overlong code refuses truncation',async()=>refusal(await invoke('Projects.WIPMethod.Get',{code:'123456789012345678901'}),'InvalidParameterFormat'));
   await seed('Job WIP Method',{Code:system,Description:'Owned synthetic system method','System Defined':true,Valid:true});
   await check('Set refuses system-defined valid-only update',async()=>{const r=refusal(await invoke('Projects.WIPMethod.Set',{code:system,valid:false}),'PreconditionFailed');const read=success(await invoke('Projects.WIPMethod.Get',{code:system}));assert(read.methods[0].valid&&read.methods[0].systemDefined,'System-defined method changed');return r;});
   success(await invoke('Projects.WIPMethod.Set',{code:posted,description:'Owned posted method'}));
   success(await invoke('Projects.WIPMethod.Set',{code:calc,description:'Owned calculated method'}));
   // Synthetic owned ledger rows exercise history guards; no financial posting or live provider is called.
   const entry=1600000000+Math.floor(Math.random()*100000000);
   await seed('Job WIP G/L Entry',{'Entry No.':entry,'WIP Method Used':posted,Reversed:true});
   await seed('Job WIP Entry',{'Entry No.':entry,'WIP Method Used':calc});
   await check('Set refuses reversed posted WIP history',async()=>refusal(await invoke('Projects.WIPMethod.Set',{code:posted,description:'Must not change'}),'PreconditionFailed'));
   await check('Set refuses calculated WIP history',async()=>refusal(await invoke('Projects.WIPMethod.Set',{code:calc,valid:false}),'PreconditionFailed'));
   await check('Both types expose localized discovery and English chapters',async()=>{
    const r=success(await invoke('Help.Implementation.Get',{messageTypes:['Projects.WIPMethod.Get','Projects.WIPMethod.Set'],detail:'full',lcid}));output.help[lcid]=r;return r;
   });
  }finally{
   await clean('Job WIP G/L Entry','WIP Method Used',posted);
   await clean('Job WIP Entry','WIP Method Used',calc);
   await seed('Job WIP Method',{Code:system,'System Defined':false});
   for(const owned of codes)await clean('Job WIP Method','Code',owned);
  }
 }
 output.completedAt=new Date().toISOString();
 }finally{save();await client.close();}
 output.summary={executed:output.rows.length,passed:output.rows.filter(x=>x.pass).length,failed:output.rows.filter(x=>!x.pass).length,skipped:0};save();console.log(JSON.stringify(output.summary));
})().catch(e=>{output.error=e.message;save();console.error(e.message);process.exit(1);});
