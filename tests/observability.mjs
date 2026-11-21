import fs from 'node:fs';import assert from 'node:assert/strict';import {execFileSync} from 'node:child_process';import {setTimeout as delay} from 'node:timers/promises';
const env=Object.fromEntries(fs.readFileSync('.env','utf8').trim().split(/\r?\n/).map(l=>l.split('=')));
const admin='Basic '+Buffer.from('admin:'+env.GRAFANA_PASSWORD).toString('base64');
const operator='Basic '+Buffer.from('operator:'+env.OPERATOR_PASSWORD).toString('base64');
async function get(url,authorization){const r=await fetch(url,{headers:authorization?{Authorization:authorization}:{},signal:AbortSignal.timeout(5000)});assert.equal(r.status,200,url);return r.json();}
const deadline=Date.now()+45000;let targets;
do{targets=await get('http://127.0.0.1:19090/api/v1/targets');if(targets.data.activeTargets.length===4&&targets.data.activeTargets.every(t=>t.health==='up'))break;await delay(500);}while(Date.now()<deadline);
assert.equal(targets.data.activeTargets.length,4);assert.ok(targets.data.activeTargets.every(t=>t.health==='up'));
const dashboard=await get('http://127.0.0.1:13000/api/dashboards/uid/bankcore-overview',admin);assert.ok(dashboard.dashboard.panels.length>=14);
const rules=await get('http://127.0.0.1:19090/api/v1/rules');assert.ok(JSON.stringify(rules).includes('DeadLetterQueueNotEmpty'));
const metrics=await fetch('http://127.0.0.1:28180/projection/actuator/prometheus',{headers:{Authorization:operator}}).then(r=>r.text());assert.match(metrics,/dlq_count/);assert.match(metrics,/sqs_messages_visible/);assert.match(metrics,/consumer_latency_seconds/);
const log=execFileSync('docker',['compose','logs','--no-color','projection-worker'],{encoding:'utf8'}).split('\n').map(l=>{try{return JSON.parse(l.slice(l.indexOf('{')));}catch{return null;}}).filter(Boolean);
assert.ok(log.some(l=>l.action==='projection_process'&&l.outcome==='committed'&&l.traceId&&l.correlationId&&l.service==='projection-worker'));
const trace=JSON.parse(fs.readFileSync('artifacts/trace.json','utf8'));assert.ok(JSON.stringify(trace).includes('ledger.db.work'));assert.ok(JSON.stringify(trace).includes('outbox.publish'));
const result={proof:'OBSERVABILITY',status:'PASS',actual:'4 Prometheus targets up; 14 Grafana panels; DLQ alert loaded; queue/DLQ/consumer latency metrics; correlated JSON async log; actual DB-work/outbox trace spans'};fs.writeFileSync('artifacts/observability-results.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));
