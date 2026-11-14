'use strict';
const fs=require('node:fs');
const {execFileSync}=require('node:child_process');
const {chromium}=require('/opt/agent/node_modules/playwright');
const dir=__dirname;
const out={sha:execFileSync('git',['-C','/workspace/private/projects16-worker4','rev-parse','HEAD'],{encoding:'utf8'}).trim(),tenant:'w129-14',changedProductPages:[],changedProductActions:[],scope:'Supplemental native WIP Methods readback of records created by the new message type; no product page/action changed.',rows:[],cleanup:[]};
function invoke(type,data,lcid=1033){const raw=JSON.parse(execFileSync('node',['/workspace/tools/origo-call.cjs','invoke_message_type',JSON.stringify({type,data,lcid})],{encoding:'utf8',maxBuffer:4*1024*1024}));const r=JSON.parse(raw.content.find(x=>x.type==='text').text.split('\n\n---')[0]);if(r.status!=='Success')throw Error(type+' failed: '+JSON.stringify(r));return r;}
(async()=>{
 const credentials=JSON.parse(fs.readFileSync('/run/agent-secrets/local-bc/webclient.json','utf8'));
 const browser=await chromium.launch({headless:true,args:['--no-sandbox']});
 const codes=[];
 const base='http://host.docker.internal:8080/BC290/?tenant=w129-14&company=CRONUS%20International%20Ltd.';
 try{
  const page=await browser.newPage();page.setDefaultTimeout(15000);page.setDefaultNavigationTimeout(30000);
  await page.goto(base+'&page=70009200');
  await page.getByRole('textbox',{name:'User name:'}).fill(credentials.user);
  await page.getByRole('textbox',{name:'Password:'}).fill(credentials.password);
  await page.getByRole('button',{name:'Sign In',exact:true}).click();
  const frame=page.frameLocator('iframe').first();
  await frame.getByText(/^(Projects Setup|Uppsetning verkefna)$/).first().waitFor();
  async function click(fn){for(let i=0;i<80;i++){for(const fr of page.frames()){const l=fn(fr);if(await l.isVisible().catch(()=>false)){await l.click();return;}}await page.waitForTimeout(200);}throw Error('UI control not found');}
  async function language(name,lcid){
   await click(fr=>fr.getByRole('button',{name:/^(Settings|Stillingar)$/}));
   await click(fr=>fr.getByText(/^(My Settings|Mínar stillingar)$/));
   await click(fr=>fr.locator('[aria-label="Review or update the value for Language"],[aria-label*="Tungumál"][role="button"]').first());
   await page.waitForTimeout(500);
   let row=frame.getByRole('row').filter({hasText:name}).last();
   if(!await row.isVisible().catch(()=>false)){
    await frame.locator('[title^="Search"],[title^="Leita"]').last().click();
    await frame.locator('[aria-label="Search Available Languages"],[aria-label="Leita Tiltæk tungumál"]').fill(name);
    await page.waitForTimeout(500);
   }
   await row.dblclick();await page.waitForTimeout(500);
   for(let i=0;i<3;i++){const ok=frame.getByRole('button',{name:/^(OK|Í lagi)$/}).last();if(!await ok.isVisible().catch(()=>false))break;await ok.click();await page.waitForTimeout(1000);}
   await page.goto(base+'&page=70009200');
   await frame.getByText(lcid===1033?'Projects Setup':'Uppsetning verkefna',{exact:true}).first().waitFor();
  }
  for(const [lcid,name] of [[1033,'English (United States)'],[1039,'Icelandic (Iceland)']]){
   const code='X16UI'+lcid+Date.now().toString().slice(-6);codes.push(code);
   invoke('Projects.WIPMethod.Set',{code,description:'Owned WIP method UI '+lcid,recognizedCosts:'Usage (Total Cost)',recognizedSales:'Contract (Invoiced Price)',wipCost:false,wipSales:false,valid:true},lcid);
   await language(name,lcid);
   await page.goto(base+'&page=1010&filter='+encodeURIComponent("'Job WIP Method'.'Code' IS '"+code+"'"));
   await frame.getByText(code,{exact:true}).first().waitFor();await page.waitForTimeout(800);
   const body=await frame.locator('body').innerText();
   const row=frame.getByRole('row').filter({hasText:code}).first();
   const rowText=await row.innerText();
   const pass=rowText.includes(code)&&rowText.includes('Owned WIP method UI '+lcid);
   const checkboxes=await row.getByRole('checkbox').evaluateAll(nodes=>nodes.map(n=>({name:n.getAttribute('aria-label'),checked:n.getAttribute('aria-checked')})));
   out.rows.push({lcid,scenario:'nativeWIPMethodsReadback',pass,code,rowText,checkboxes,body});
   await page.screenshot({path:dir+'/ui-'+lcid+'-wip-method.png'});
   fs.writeFileSync(dir+'/ui-results.json',JSON.stringify(out,null,2));
   if(!pass)throw Error('Native WIP method not visible in '+lcid);
  }
  await language('English (United States)',1033);out.restoredLanguage=1033;
 }finally{
  await browser.close();
  for(const code of codes){out.cleanup.push({code,result:invoke('Test.Records.Delete',{tableName:'Job WIP Method',tableView:'WHERE(Code=CONST('+code+'))'})});}
  out.completedAt=new Date().toISOString();out.summary={executed:out.rows.length,passed:out.rows.filter(x=>x.pass).length,failed:out.rows.filter(x=>!x.pass).length,skipped:0};
  fs.writeFileSync(dir+'/ui-results.json',JSON.stringify(out,null,2));
 }
 console.log(JSON.stringify(out.summary));
})().catch(e=>{out.error=e.message;fs.writeFileSync(dir+'/ui-results.json',JSON.stringify(out,null,2));console.error(e.message);process.exit(1);});
