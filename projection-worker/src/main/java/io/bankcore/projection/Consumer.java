package io.bankcore.projection;
import org.springframework.stereotype.Component;import org.springframework.beans.factory.annotation.Value;import org.springframework.scheduling.annotation.Scheduled;
import software.amazon.awssdk.services.sqs.SqsClient;import io.micrometer.core.instrument.MeterRegistry;import io.bankcore.platform.TraceSupport;
import org.slf4j.*;
@Component public class Consumer {
 final Projection projection;final SqsClient sqs;final MeterRegistry meters;final String queue;final TraceSupport traces;
 final Logger log=LoggerFactory.getLogger(getClass());
 public Consumer(Projection projection,SqsClient sqs,MeterRegistry meters,@Value("${bankcore.queue-url}")String queue,TraceSupport traces){this.projection=projection;this.sqs=sqs;this.meters=meters;this.queue=queue;this.traces=traces;}
 @Scheduled(fixedDelayString="800") public void poll(){
  try{
   var messages=sqs.receiveMessage(b->b.queueUrl(queue).maxNumberOfMessages(5).waitTimeSeconds(1).messageAttributeNames("All")).messages();
   for(var message:messages){
    try{
     var attrs=message.messageAttributes();String parent=attrs.containsKey("traceparent")?attrs.get("traceparent").stringValue():null;String correlation=attrs.containsKey("correlation_id")?attrs.get("correlation_id").stringValue():null;
     traces.run(parent,correlation,"projection.process",()->projection.apply(message.body()));
     sqs.deleteMessage(b->b.queueUrl(queue).receiptHandle(message.receiptHandle()));meters.counter("consumer.processing").increment();
     log.atInfo().addKeyValue("action","projection_process").addKeyValue("outcome","committed").log("Projection committed before acknowledgement");
    }catch(RuntimeException e){meters.counter("consumer.failures").increment();log.atWarn().addKeyValue("action","projection_process").addKeyValue("outcome","redelivery").log("Message left unacknowledged");}
   }
  }catch(RuntimeException e){meters.counter("consumer.failures").increment();}
 }
}
