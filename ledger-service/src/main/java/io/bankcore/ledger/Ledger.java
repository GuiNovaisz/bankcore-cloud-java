package io.bankcore.ledger;
import java.util.*;import java.math.BigDecimal;
import org.springframework.stereotype.Service;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.tracing.Tracer;
import org.slf4j.*;
import io.bankcore.platform.ApiErrors.Rejected;

@Service
public class Ledger {
 static final UUID TREASURY=UUID.fromString("00000000-0000-0000-0000-000000000001");
 public record Command(UUID id,UUID source,UUID destination,BigDecimal amount,String currency){}
 final JdbcTemplate db;final ObjectMapper json;final MeterRegistry meters;final Tracer tracer;
 final Logger log=LoggerFactory.getLogger(getClass());
 public Ledger(JdbcTemplate db,ObjectMapper json,MeterRegistry meters,Tracer tracer){this.db=db;this.json=json;this.meters=meters;this.tracer=tracer;}
 @Transactional public Map<String,Object> post(Command request,boolean funding){
  var dbSpan=tracer.nextSpan().name("ledger.db.work").start();
  var sample=io.micrometer.core.instrument.Timer.start(meters);
  try(var scope=tracer.withSpan(dbSpan)){
  var money=new Money(request.amount(),request.currency());
  if(request.id()==null || request.source()==null || request.destination()==null || request.source().equals(request.destination()))throw new IllegalArgumentException();
  if(TREASURY.equals(request.destination()) || (!funding && TREASURY.equals(request.source())))throw new Rejected(403,"RESERVED_ACCOUNT");
  db.queryForObject("select pg_advisory_xact_lock(hashtextextended(?,0))",Object.class,request.id().toString());
  var existing=db.queryForList("select * from journal where id=?",request.id());
  if(!existing.isEmpty()){
   var j=existing.getFirst();
   if(!j.get("source").equals(request.source()) || !j.get("destination").equals(request.destination()) || ((BigDecimal)j.get("amount")).compareTo(money.amount())!=0 || !j.get("currency").equals(money.currency()))throw new Rejected(409,"IDEMPOTENCY_CONFLICT");
   return j;
  }
  var accounts=db.queryForList("select * from ledger_account where id in (?,?) order by id for update",request.source(),request.destination());
  if(accounts.size()!=2)throw new Rejected(422,"ACCOUNT_NOT_PROVISIONED");
  if(accounts.stream().anyMatch(a->!Boolean.TRUE.equals(a.get("enabled"))))throw new Rejected(422,"ACCOUNT_INACTIVE");
  var source=accounts.stream().filter(a->a.get("id").equals(request.source())).findFirst().orElseThrow();
  if(!funding && ((BigDecimal)source.get("balance")).compareTo(money.amount())<0)throw new Rejected(422,"INSUFFICIENT_FUNDS");
  db.update("insert into journal(id,source,destination,amount,currency) values(?,?,?,?,?)",request.id(),request.source(),request.destination(),money.amount(),money.currency());
  db.update("insert into posting(journal_id,account_id,side,amount) values(?,?,'DEBIT',?),(?,?,'CREDIT',?)",request.id(),request.source(),money.amount(),request.id(),request.destination(),money.amount());
  try {
   var event=new LinkedHashMap<String,Object>();event.put("eventId",request.id());event.put("type","LedgerEntryPosted");event.put("schemaVersion",1);event.put("source",request.source());event.put("destination",request.destination());event.put("amount",money.amount().toPlainString());event.put("currency",money.currency());
   String parent=null;var span=tracer.currentSpan();if(span!=null)parent="00-"+span.context().traceId()+"-"+span.context().spanId()+"-01";
   db.update("insert into outbox(id,payload,traceparent,correlation_id) values(?,?,?,?)",request.id(),json.writeValueAsString(event),parent,MDC.get("correlationId"));
  }catch(com.fasterxml.jackson.core.JsonProcessingException e){throw new IllegalStateException(e);}
  meters.counter("ledger.postings").increment(2);log.atInfo().addKeyValue("action","journal_posted").addKeyValue("outcome","committed_on_transaction_exit").log("Ledger posting prepared");
  return db.queryForMap("select * from journal where id=?",request.id());
  }catch(RuntimeException e){dbSpan.error(e);throw e;}
  finally{sample.stop(meters.timer("ledger.db.latency"));dbSpan.end();}
 }
}
