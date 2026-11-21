package io.bankcore.ledger;
import java.time.Duration;import java.net.URI;import java.util.*;
import org.springframework.stereotype.Component;import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.beans.factory.annotation.Value;import org.springframework.context.annotation.*;
import org.springframework.jdbc.core.JdbcTemplate;import org.springframework.transaction.support.TransactionTemplate;
import io.micrometer.core.instrument.MeterRegistry;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.MessageAttributeValue;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import org.slf4j.*;

@Configuration class SqsConfiguration {
 @Bean(destroyMethod="close") SqsClient sqs(@Value("${bankcore.sqs-endpoint}")String endpoint,@Value("${bankcore.region}")String region){
  var builder=SqsClient.builder().region(Region.of(region)).httpClientBuilder(UrlConnectionHttpClient.builder().connectionTimeout(Duration.ofMillis(400)).socketTimeout(Duration.ofSeconds(3)))
   .overrideConfiguration(c->c.apiCallTimeout(Duration.ofSeconds(4)).apiCallAttemptTimeout(Duration.ofSeconds(3)).retryPolicy(r->r.numRetries(0)));
  if(!endpoint.isBlank())builder.endpointOverride(URI.create(endpoint));return builder.build();
 }
}
@Component public class OutboxPublisher {
 final JdbcTemplate db;final TransactionTemplate tx;final SqsClient sqs;final MeterRegistry meters;final String queue;final io.bankcore.platform.TraceSupport traces;
 final Logger log=LoggerFactory.getLogger(getClass());
 public OutboxPublisher(JdbcTemplate db,TransactionTemplate tx,SqsClient sqs,MeterRegistry meters,@Value("${bankcore.queue-url}")String queue,io.bankcore.platform.TraceSupport traces){this.db=db;this.tx=tx;this.sqs=sqs;this.meters=meters;this.queue=queue;this.traces=traces;meters.gauge("outbox.pending",this,p->p.db.queryForObject("select count(*) from outbox where published_at is null",Long.class));}
 @Scheduled(fixedDelayString="1000") public void publish(){
  try{tx.executeWithoutResult(status->{
   var rows=db.queryForList("select * from outbox where published_at is null and next_attempt_at<=now() order by created_at limit 10 for update skip locked");
   for(var row:rows)traces.run((String)row.get("traceparent"),(String)row.get("correlation_id"),"outbox.publish",()->{
    try{
     var attrs=new HashMap<String,MessageAttributeValue>();
     for(String key:List.of("traceparent","correlation_id"))if(row.get(key)!=null)attrs.put(key,MessageAttributeValue.builder().dataType("String").stringValue(row.get(key).toString()).build());
     if(traces.parent()!=null)attrs.put("traceparent",MessageAttributeValue.builder().dataType("String").stringValue(traces.parent()).build());
     sqs.sendMessage(b->b.queueUrl(queue).messageBody(row.get("payload").toString()).messageAttributes(attrs));
     db.update("update outbox set published_at=now(),attempts=attempts+1 where id=?",row.get("id"));
    }catch(RuntimeException e){
     meters.counter("outbox.publish.failures").increment();
     db.update("update outbox set attempts=attempts+1,next_attempt_at=now()+make_interval(secs => least(60,power(2,least(attempts,5))::int))+random()*interval '500 milliseconds' where id=?",row.get("id"));
     log.atWarn().addKeyValue("action","outbox_publish").addKeyValue("outcome","retry_scheduled").log("SQS publication deferred");
    }
   });
  });}catch(RuntimeException e){log.atWarn().addKeyValue("action","outbox_poll").addKeyValue("outcome","unavailable").log("Outbox database unavailable");}
 }
}
