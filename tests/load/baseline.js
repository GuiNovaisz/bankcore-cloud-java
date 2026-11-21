import http from 'k6/http';
import {check,sleep} from 'k6';
import {Trend,Rate} from 'k6/metrics';
const processing=new Trend('transfer_processing_ms',true);
const failures=new Rate('logical_transfer_error_rate');
const base=__ENV.BASE_URL||'http://edge:8080';
const headers={Authorization:'Basic '+__ENV.BASIC_AUTH,'Content-Type':'application/json'};
export const options={summaryTrendStats:['avg','min','med','p(50)','p(95)','p(99)','max'],
 scenarios:{steady:{executor:'constant-vus',vus:2,duration:'15s',exec:'normal'},burst:{executor:'constant-vus',vus:4,duration:'10s',startTime:'16s',exec:'normal'},concurrent:{executor:'constant-vus',vus:2,duration:'10s',startTime:'27s',exec:'normal'},duplicates:{executor:'constant-vus',vus:2,duration:'10s',startTime:'38s',exec:'duplicate'}},
 thresholds:{logical_transfer_error_rate:['rate==0'],http_req_failed:['rate<0.01']}};
function uuid(){return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g,c=>{const r=Math.floor(Math.random()*16);return(c==='x'?r:(r&3)|8).toString(16);});}
function post(path,body,extra={}){return http.post(base+path,JSON.stringify(body),{headers:{...headers,...extra},timeout:'10s'});}
export function setup(){const source=uuid(),destination=uuid();for(const id of [source,destination]){const r=post('/account/accounts',{id,ownerReference:'load-'+id});if(r.status!==200)throw new Error('Account fixture failed '+r.status);}const r=post('/ledger/admin/funding',{id:uuid(),destination:source,amount:'100000.00',currency:'BRL'});if(r.status!==200)throw new Error('Funding fixture failed');return {source,destination,duplicateKey:uuid()};}
function submit(data,key){const start=Date.now();const r=post('/transfer/transfers',{source:data.source,destination:data.destination,amount:'0.01',currency:'BRL'},{'Idempotency-Key':key});if(!check(r,{'transfer accepted':r=>r.status===202})){failures.add(true);return;}const id=r.json('id');let status;for(let i=0;i<100;i++){const s=http.get(base+'/transfer/transfers/'+id,{headers,timeout:'10s'});if(s.status===200)status=s.json('status');if(status==='COMPLETED'||status==='FAILED')break;sleep(0.2);}failures.add(status!=='COMPLETED');processing.add(Date.now()-start);}
export function normal(data){submit(data,uuid());sleep(0.2);}
export function duplicate(data){submit(data,data.duplicateKey);sleep(0.2);}
