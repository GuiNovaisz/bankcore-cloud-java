import fs from 'node:fs';import {spawnSync} from 'node:child_process';
const env=Object.fromEntries(fs.readFileSync('.env','utf8').trim().split(/\r?\n/).map(l=>l.split('=')));
const r=spawnSync('docker',['compose','--profile','load','run','--rm','k6'],{stdio:'inherit',env:{...process.env,LOAD_BASIC_AUTH:Buffer.from('operator:'+env.OPERATOR_PASSWORD).toString('base64')}});process.exit(r.status??1);
