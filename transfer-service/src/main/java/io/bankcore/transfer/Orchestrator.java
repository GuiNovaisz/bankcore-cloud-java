package io.bankcore.transfer;
import java.util.*;import org.springframework.stereotype.Component;import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.support.TransactionTemplate;import org.springframework.web.client.*;
import io.github.resilience4j.circuitbreaker.*;import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.*;
@Component public class Orchestrator {
 final JdbcTemplate db;final TransactionTemplate tx;final RestClient http;final CircuitBreaker accounts;final String accountUrl,ledgerUrl;final MeterRegistry meters;
 final Logger log=LoggerFactory.getLogger(getClass());final io.bankcore.platform.TraceSupport traces;
 public Orchestrator(JdbcTemplate db,TransactionTemplate tx,RestClient http,CircuitBreakerRegistry breakers,@Value("${bankcore.account-url}")String accountUrl,@Value("${bankcore.ledger-url}")String ledgerUrl,MeterRegistry meters,io.bankcore.platform.TraceSupport traces){this.db=db;this.tx=tx;this.http=http;this.accounts=breakers.circuitBreaker("account");this.accountUrl=accountUrl;this.ledgerUrl=ledgerUrl;this.meters=meters;this.traces=traces;}
 @Scheduled(fixedDelayString="700") public void poll(){
  try{tx.executeWithoutResult(s->{
   var rows=db.queryForList("select * from transfer where status in ('REQUESTED','PROCESSING') and next_attempt_at<=now() order by created_at limit 5 for update skip locked");
   for(var r:rows)traces.run((String)r.get("traceparent"),(String)r.get("correlation_id"),"transfer.process",()->process(r));
  });}catch(RuntimeException e){log.atWarn().addKeyValue("action","transfer_poll").addKeyValue("outcome","unavailable").log("Transfer poll deferred");}
 }
 void process(Map<String,Object> r){
  var sample=io.micrometer.core.instrument.Timer.start(meters);
  try{
   boolean posted=false;
   try{http.get().uri(ledgerUrl+"/internal/journals/"+r.get("id")).retrieve().toBodilessEntity();posted=true;}catch(HttpClientErrorException.NotFound missing){/* Absence is safe to retry with the same journal id. */}
   if(!posted){
    for(String key:List.of("source","destination")){
     var account=accounts.executeSupplier(()->http.get().uri(accountUrl+"/internal/accounts/"+r.get(key)).retrieve().body(Map.class));
     if(account==null||!"ACTIVE".equals(account.get("status"))){fail(r,"ACCOUNT_INACTIVE");return;}
    }
    http.post().uri(ledgerUrl+"/internal/journals").body(Map.of("id",r.get("id"),"source",r.get("source"),"destination",r.get("destination"),"amount",r.get("amount"),"currency",r.get("currency"))).retrieve().toBodilessEntity();
   }
   db.update("update transfer set status='COMPLETED',completed_at=now(),attempts=attempts+1 where id=?",r.get("id"));meters.counter("transfer.completed").increment();
   log.atInfo().addKeyValue("action","transfer_process").addKeyValue("outcome","completed").log("Ledger confirmed transfer");
  }catch(HttpClientErrorException e){
   if(e.getStatusCode().value()==422||e.getStatusCode().value()==404||e.getStatusCode().value()==409)fail(r,"LEDGER_OR_ACCOUNT_REJECTED");else retry(r);
  }catch(RuntimeException e){retry(r);}
  finally{sample.stop(meters.timer("transfer.latency"));}
 }
 void fail(Map<String,Object> r,String code){db.update("update transfer set status='FAILED',failure_code=?,attempts=attempts+1 where id=?",code,r.get("id"));meters.counter("transfer.failed").increment();}
 void retry(Map<String,Object> r){db.update("update transfer set status='PROCESSING',attempts=attempts+1,next_attempt_at=now()+make_interval(secs => least(60,power(2,least(attempts,5))::int))+random()*interval '500 milliseconds' where id=?",r.get("id"));log.atWarn().addKeyValue("action","transfer_process").addKeyValue("outcome","pending_reconciliation").log("Transfer outcome pending");}
}
