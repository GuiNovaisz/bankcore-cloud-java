import fs from 'node:fs';import {spawnSync} from 'node:child_process';
const env=Object.fromEntries(fs.readFileSync('.env','utf8').trim().split(/\r?\n/).map(l=>l.split('=')));
const r=spawnSync('docker',['compose','--profile','load','run','--rm','k6'],{stdio:'inherit',env:{...process.env,LOAD_BASIC_AUTH:Buffer.from('operator:'+env.OPERATOR_PASSWORD).toString('base64')}});
if(r.status===0){const file='artifacts/load-summary.json';const summary=JSON.parse(fs.readFileSync(file,'utf8'));delete summary.setup_data;fs.writeFileSync(file,JSON.stringify(summary,null,2)+'\n');}
process.exit(r.status??1);
