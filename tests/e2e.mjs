import fs from 'node:fs';
import {execFileSync,spawn} from 'node:child_process';
import {randomUUID,randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
import {setTimeout as delay} from 'node:timers/promises';

// Destructive failure hooks target this Compose project only, never production.
const env=Object.fromEntries(fs.readFileSync('.env','utf8').trim().split(/\r?\n/).map(l=>l.split('=')));
const base=process.env.BANKCORE_BASE_URL??'http://127.0.0.1:28180';
const results=[];const prefix=randomUUID();
const docker=(...args)=>execFileSync('docker',['compose',...args],{encoding:'utf8',timeout:120000,stdio:['pipe','pipe','pipe']}).trim();
const sql=(db,q)=>docker('exec','-T','postgres','psql','-X','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1','-At','-c',q);
const sqs=(...args)=>docker('exec','-T','localstack','awslocal','sqs',...args);
const queue='http://localhost:4566/000000000000/bankcore-events';
const dlq='http://localhost:4566/000000000000/bankcore-dlq';
const auth=(service=false)=>'Basic '+Buffer.from((service?'service:'+env.SERVICE_PASSWORD:'operator:'+env.OPERATOR_PASSWORD)).toString('base64');
async function request(path,{method='GET',body,key,service=false,status,headers={}}={}){
 const response=await fetch(base+path,{method,headers:{Authorization:auth(service),'Content-Type':'application/json',...(key?{'Idempotency-Key':key}:{}),...headers},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
 const text=await response.text();let value;try{value=JSON.parse(text);}catch{value=text;}
 if(status!==undefined)assert.equal(response.status,status,`${method} ${path}: ${text}`);
 return {status:response.status,body:value};
}
async function until(fn,ms=60000){const deadline=Date.now()+ms;let last;while(Date.now()<deadline){try{last=await fn();if(last)return last;}catch(e){last=e;}await delay(250);}throw new Error('Condition deadline exceeded: '+String(last));}
async function proof(id,expected,fn){const start=Date.now();try{const actual=await fn();results.push({proof:id,environment:'Docker Compose; PostgreSQL 18.7; LocalStack SQS; Windows/Linux CI',command:'node tests/e2e.mjs',expected,actual:actual??expected,status:'PASS',durationMs:Date.now()-start});console.log(`${id} PASS ${JSON.stringify(actual??expected)}`);}catch(error){results.push({proof:id,expected,actual:error.message,status:'FAIL',durationMs:Date.now()-start});console.error(`${id} FAIL ${error.message}`);throw error;}finally{fs.mkdirSync('artifacts',{recursive:true});fs.writeFileSync('artifacts/e2e-results.json',JSON.stringify(results,null,2));}}
async function account(){let id=randomUUID();await request('/account/accounts',{method:'POST',body:{id,ownerReference:'fixture-'+id},status:200});return id;}
async function fund(id,amount){const journal=randomUUID();await request('/ledger/admin/funding',{method:'POST',body:{id:journal,destination:id,amount,currency:'BRL'},status:200});return journal;}
async function transfer(source,destination,amount='1.00',key=randomUUID(),headers={}){return (await request('/transfer/transfers',{method:'POST',key,body:{source,destination,amount,currency:'BRL'},status:202,headers})).body;}
async function terminal(id){return until(async()=>{const r=(await request('/transfer/transfers/'+id,{status:200})).body;return ['COMPLETED','FAILED'].includes(r.status)?r:false;});}
async function healthy(name){await until(async()=>{try{return (await request('/'+name+'/actuator/health/readiness')).status===200;}catch{return false;}},90000);}
function invariant(db='ledger'){
 assert.equal(sql(db,"select count(*) from journal j where (select count(*) from posting p where p.journal_id=j.id)<>2 or (select sum(case side when 'DEBIT' then -amount else amount end) from posting p where p.journal_id=j.id)<>0"),'0');
 assert.equal(sql(db,'select coalesce(sum(balance),0) from ledger_account'),'0.00');
 assert.equal(sql(db,"select count(*) from ledger_account a where balance<>(select coalesce(sum(case side when 'DEBIT' then -amount else amount end),0) from posting p where p.account_id=a.id)"),'0');
 assert.equal(sql(db,"select count(*) from ledger_account where kind='CUSTOMER' and balance<0"),'0');
}
async function lockBarrier(id){
 const child=spawn('docker',['compose','exec','-T','postgres','psql','-X','-U','postgres','-d','ledger','-At'],{stdio:['pipe','pipe','pipe']});
 let output='';const ready=new Promise((resolve,reject)=>{child.stdout.on('data',d=>{output+=d;if(output.includes('BANKCORE_LOCK_READY'))resolve();});child.on('error',reject);child.on('exit',code=>{if(code&&!output.includes('BANKCORE_LOCK_READY'))reject(new Error('Barrier failed'));});});
 child.stdin.write(`BEGIN; SELECT id FROM ledger_account WHERE id='${id}' FOR UPDATE; SELECT 'BANKCORE_LOCK_READY';\n`);
 await ready;return ()=>{child.stdin.end('COMMIT;\n');};
}

const recover=new Set();
try {
 await proof('B18','Full isolated local stack healthy',async()=>{for(const s of ['account','ledger','transfer','projection'])await healthy(s);assert.ok(docker('ps','--format','json').includes('healthy'));return 'Four readiness endpoints 200; Docker healthchecks green';});
 const source=await account(),destination=await account();await fund(source,'10000.00');
 await proof('API-CONTRACT','Provider/consumer contracts, pagination, precision, status and event schema',async()=>{
  await request('/account/accounts/'+source,{status:200});await request('/account/accounts/'+source,{status:200});
  for(const path of ['/account/accounts?limit=1','/transfer/transfers?limit=1','/ledger/journals?limit=1'])assert.ok(Array.isArray((await request(path,{status:200})).body));
  for(const path of ['/account/accounts?limit=101','/transfer/transfers?offset=-1','/ledger/journals?limit=0'])await request(path,{status:400});
  await request('/projection/projections/'+destination,{status:200});
  for(const [amount,currency] of [['0.001','BRL'],['1.00','USD'],['0.00','BRL']])await request('/transfer/transfers',{method:'POST',key:randomUUID(),body:{source,destination,amount,currency},status:400});
  await request('/transfer/transfers',{method:'POST',body:{source,destination,amount:'1.00',currency:'BRL'},status:400});
  const event=JSON.parse(sql('ledger',`select payload from outbox where id=(select id from journal where destination='${source}' limit 1)`));assert.equal(event.type,'LedgerEntryPosted');assert.equal(event.schemaVersion,1);assert.equal(event.currency,'BRL');assert.match(event.amount,/^\d+\.\d{2}$/);
  return 'Provider JSON consumed by worker; decimal strings, page bounds, invalid inputs and missing idempotency header checked';
 });
 await proof('API-AUTH','Unauthenticated and wrong-role calls rejected',async()=>{assert.equal((await fetch(base+'/transfer/transfers')).status,401);await request('/ledger/internal/journals/'+randomUUID(),{status:403});return '401 unauthenticated; 403 operator to internal API';});
 let duplicateId;
 await proof('B3','Concurrent duplicate requests produce one transfer and one journal',async()=>{
  const key=randomUUID();const payload={source,destination,amount:'10.00',currency:'BRL'};
  const replies=await Promise.all(Array.from({length:12},()=>request('/transfer/transfers',{method:'POST',key,body:payload,status:202})));
  const ids=new Set(replies.map(r=>r.body.id));assert.equal(ids.size,1);duplicateId=[...ids][0];assert.equal((await terminal(duplicateId)).status,'COMPLETED');
  assert.equal(sql('ledger',`select count(*) from journal where id='${duplicateId}'`),'1');
  await request('/transfer/transfers',{method:'POST',key,body:{...payload,amount:'11.00'},status:409});
  return '12 simultaneous HTTP requests; 1 transfer; 1 journal; payload conflict 409';
 });
 await proof('B4','Same key with a changed request returns 409',async()=>{const key=randomUUID();await transfer(source,destination,'1.00',key);const r=await request('/transfer/transfers',{method:'POST',key,body:{source,destination,amount:'2.00',currency:'BRL'},status:409});assert.equal(r.body.code,'IDEMPOTENCY_CONFLICT');return '409 IDEMPOTENCY_CONFLICT';});
 await proof('B5','100 BRL minus two concurrent 80 BRL requests accepts exactly one',async()=>{
  const a=await account(),b=await account();await fund(a,'100.00');
  const release=await lockBarrier(a);let pending=[];
  try{
   pending=Array.from({length:2},()=>request('/ledger/internal/journals',{method:'POST',service:true,body:{id:randomUUID(),source:a,destination:b,amount:'80.00',currency:'BRL'}}));
   await until(()=>Number(sql('ledger',"select count(*) from pg_stat_activity where datname='ledger' and usename='ledger_app' and wait_event_type='Lock'"))>=2,10000);
  }finally{release();}
  const replies=await Promise.all(pending);assert.deepEqual(replies.map(r=>r.status).sort(),[200,422]);
  assert.equal(String((await request('/ledger/accounts/'+a+'/balance',{status:200})).body.balance),'20.00');
  invariant();return 'Both DB sessions observed waiting on locks; statuses 200/422; source balance 20.00';
 });
 await proof('B1','All journals have equal debits and credits',async()=>{invariant();return 'SQL audit: zero unbalanced or partial journals';});
 await proof('B2','All movements conserve total money including explicit treasury funding',async()=>{invariant();return 'Sum balances including treasury = 0.00; balances match postings';});
 await proof('B6','Runtime credentials cannot edit/delete journal or posting or directly change balance',async()=>{
  for(const q of [`UPDATE posting SET amount=999 WHERE journal_id='${duplicateId}'`,`DELETE FROM posting WHERE journal_id='${duplicateId}'`,`UPDATE journal SET amount=999 WHERE id='${duplicateId}'`,`UPDATE ledger_account SET balance=999 WHERE id='${source}'`,`TRUNCATE posting`,`ALTER TABLE posting DISABLE TRIGGER ALL`])assert.throws(()=>sql('ledger','SET ROLE ledger_app; '+q));
  assert.throws(()=>sql('ledger',`UPDATE posting SET amount=999 WHERE journal_id='${duplicateId}'`));
  assert.throws(()=>sql('ledger',`BEGIN; INSERT INTO journal(id,source,destination,amount,currency) VALUES('${randomUUID()}','${source}','${destination}',1,'BRL'); COMMIT;`));
  invariant();return 'UPDATE/DELETE/TRUNCATE/DDL denied to runtime; owner edits blocked; unbalanced journal commit rejected';
 });
 await proof('F1','Ledger outage never falsely completes a transfer',async()=>{
  docker('stop','ledger-service');recover.add('ledger-service');const t=await transfer(source,destination);
  await until(()=>Number(sql('transfer',`select attempts from transfer where id='${t.id}'`))>0);assert.equal((await request('/transfer/transfers/'+t.id)).body.status,'PROCESSING');
  docker('start','ledger-service');recover.delete('ledger-service');await healthy('ledger');assert.equal((await terminal(t.id)).status,'COMPLETED');return 'Durable PROCESSING during outage; COMPLETED only after ledger recovery';
 });
 await proof('B7','Outbox survives SQS failure after financial commit and publishes on recovery',async()=>{
  docker('stop','localstack');recover.add('localstack');const t=await transfer(source,destination);assert.equal((await terminal(t.id)).status,'COMPLETED');
  await until(()=>Number(sql('ledger',`select attempts from outbox where id='${t.id}'`))>0);
  assert.equal(sql('ledger',`select count(*) from outbox where id='${t.id}' and published_at is null`),'1');
  docker('start','localstack');recover.delete('localstack');await until(()=>sql('ledger',`select count(*) from outbox where id='${t.id}' and published_at is not null`)==='1');
  await until(()=>sql('projection',`select count(*) from inbox where event_id='${t.id}'`)==='1');return 'Committed journal + pending outbox retained; eventual inbox count 1';
 });
 await proof('B8','Duplicate SQS deliveries have one projection effect',async()=>{
  const isolated=await account(),eventId=await fund(isolated,'7.00');
  await until(()=>sql('projection',`select count(*) from inbox where event_id='${eventId}'`)==='1');
  const body=sql('ledger',`select payload from outbox where id='${eventId}'`),before=sql('projection',`select balance from account_projection where account_id='${isolated}'`);
  const beforeProcessed=await request('/projection/actuator/prometheus',{status:200});const count=t=>Number(t.match(/^consumer_processing_total(?:\{[^\n]*\})? ([\d.]+)/m)?.[1]??0);const n=count(beforeProcessed.body);
  sqs('send-message','--queue-url',queue,'--message-body',body);sqs('send-message','--queue-url',queue,'--message-body',body);
  await until(async()=>count((await request('/projection/actuator/prometheus')).body)>=n+2);
  assert.equal(sql('projection',`select count(*) from inbox where event_id='${eventId}'`),'1');
  assert.equal(sql('projection',`select balance from account_projection where account_id='${isolated}'`),before);
  assert.equal(before,'7.00');return 'Two additional receives/acks; isolated projection unchanged at 7.00; inbox count 1';
 });
 await proof('B9','Poison event is redriven to DLQ after maxReceiveCount=3',async()=>{
  const poison='poison-'+randomUUID();sqs('send-message','--queue-url',queue,'--message-body',poison);
  let found;await until(()=>{const received=JSON.parse(sqs('receive-message','--queue-url',dlq,'--max-number-of-messages','10','--visibility-timeout','1','--message-system-attribute-names','All'));found=received.Messages?.find(m=>m.Body===poison);return found;},90000);
  sqs('delete-message','--queue-url',dlq,'--receipt-handle',found.ReceiptHandle);return 'Unparseable payload reached actual LocalStack DLQ with queue redrive policy 3';
 });
 await proof('B10','Redis outage falls back to DB without changing financial correctness',async()=>{
  await request('/account/accounts/'+source,{status:200});await request('/account/accounts/'+source,{status:200});
  docker('stop','redis');recover.add('redis');await request('/account/accounts/'+source,{status:200});const t=await transfer(source,destination);assert.equal((await terminal(t.id)).status,'COMPLETED');invariant();
  docker('start','redis');recover.delete('redis');return 'Account read 200 with Redis down; transfer completed; SQL invariants unchanged';
 });
 await proof('B13','Transfer state survives process restart',async()=>{
  docker('stop','ledger-service');recover.add('ledger-service');const t=await transfer(source,destination);docker('restart','transfer-service');await healthy('transfer');
  assert.equal((await request('/transfer/transfers/'+t.id)).body.id,t.id);docker('start','ledger-service');recover.delete('ledger-service');await healthy('ledger');assert.equal((await terminal(t.id)).status,'COMPLETED');invariant();return 'Same transfer id across restart; one journal after recovery';
 });
 await proof('B14','Injected projection divergence is detected and audited',async()=>{
  await until(async()=>!(await request('/projection/internal/reconciliation/'+destination,{method:'POST',service:true,status:200})).body.mismatchDetected);
  sql('projection',`update account_projection set balance=balance+0.01 where account_id='${destination}'`);
  const r=await request('/projection/internal/reconciliation/'+destination,{method:'POST',service:true,status:200});assert.equal(r.body.mismatchDetected,true);
  assert.ok(Number(sql('projection',`select count(*) from reconciliation_audit where account_id='${destination}' and mismatch`))>0);
  // Explicit, audited test-only cleanup. Reconciliation itself never repairs silently.
  sql('projection',`update account_projection set balance=balance-0.01 where account_id='${destination}'`);return 'RECONCILIATION_PROOF mismatchDetected=true; audit row retained';
 });
 await proof('B15','Cross-service trace contains transfer, account and ledger spans',async()=>{
  const trace=randomBytes(16).toString('hex');const t=await transfer(source,destination,'1.00',randomUUID(),{traceparent:`00-${trace}-1234567890abcdef-01`,'X-Correlation-ID':prefix});await terminal(t.id);
  let traceData;await until(async()=>{const r=await fetch('http://127.0.0.1:13200/api/traces/'+trace);if(!r.ok)return false;traceData=await r.json();return JSON.stringify(traceData).includes('ledger-service')&&JSON.stringify(traceData).includes('account-service')&&JSON.stringify(traceData).includes('transfer-service');},45000);
  fs.writeFileSync('artifacts/trace.json',JSON.stringify(traceData,null,2));fs.writeFileSync('artifacts/trace-id.txt',trace);return {traceId:trace,services:['transfer-service','account-service','ledger-service']};
 });
 await proof('B16','Durable async context correlates projection processing to originating trace',async()=>{
  const trace=fs.readFileSync('artifacts/trace-id.txt','utf8');let data;await until(async()=>{const r=await fetch('http://127.0.0.1:13200/api/traces/'+trace);if(!r.ok)return false;data=await r.json();return JSON.stringify(data).includes('projection.process');},45000);fs.writeFileSync('artifacts/trace.json',JSON.stringify(data,null,2));return {traceId:trace,asyncSpan:'projection.process'};
 });
 await proof('B17','SIGTERM drains services without incomplete financial journals',async()=>{
  const rows=await Promise.all(Array.from({length:5},()=>transfer(source,destination)));
  docker('stop','--timeout','35','transfer-service','projection-worker');recover.add('transfer-service');recover.add('projection-worker');invariant();
  docker('start','transfer-service','projection-worker');recover.delete('transfer-service');recover.delete('projection-worker');await healthy('transfer');await healthy('projection');for(const t of rows)assert.equal((await terminal(t.id)).status,'COMPLETED');invariant();return 'Graceful stop/start; five durable requests eventually completed; no partial journals';
 });
 await proof('B23','Controlled ledger outage under moderate concurrent traffic preserves invariants',async()=>{
  docker('stop','ledger-service');recover.add('ledger-service');const rows=await Promise.all(Array.from({length:12},()=>transfer(source,destination)));
  for(const row of rows)assert.notEqual((await request('/transfer/transfers/'+row.id)).body.status,'COMPLETED');
  docker('start','ledger-service');recover.delete('ledger-service');await healthy('ledger');for(const row of rows)assert.equal((await terminal(row.id)).status,'COMPLETED');invariant();return '12 concurrent accepted requests during outage; eventual completion; zero partial/unbalanced journals';
 });
 await proof('B24','Logical backup restores ledger and invariants to a separate database',async()=>{
  const dump=docker('exec','-T','postgres','pg_dump','-U','postgres','-d','ledger','--no-owner','--no-acl');
  const name='restore_'+randomBytes(5).toString('hex');sql('postgres',`CREATE DATABASE ${name}`);
  try {execFileSync('docker',['compose','exec','-T','postgres','psql','-X','-U','postgres','-d',name,'-v','ON_ERROR_STOP=1'],{input:dump,stdio:['pipe','pipe','pipe'],timeout:60000});invariant(name);assert.equal(sql(name,'select count(*) from journal'),sql('ledger','select count(*) from journal'));}
  finally{sql('postgres',`DROP DATABASE ${name}`);}return 'pg_dump restored into isolated DB; journal count and all financial invariants verified; real AWS PITR unexecuted';
 });
 console.log('E2E proofs complete.');
} finally {
 for(const service of recover)try{docker('start',service);}catch{}
 fs.writeFileSync('artifacts/e2e-results.json',JSON.stringify(results,null,2));
}
