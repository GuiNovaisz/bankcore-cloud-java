package io.bankcore.projection;

import io.micrometer.core.instrument.MeterRegistry;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.services.sqs.SqsClient;
import software.amazon.awssdk.services.sqs.model.QueueAttributeName;

@Component
public class QueueMetrics {
  final AtomicLong visible = new AtomicLong();
  final AtomicLong dlq = new AtomicLong();
  final SqsClient sqs;
  final String queue;
  final MeterRegistry meters;

  public QueueMetrics(
      SqsClient sqs, @Value("${bankcore.queue-url}") String queue, MeterRegistry meters) {
    this.sqs = sqs;
    this.queue = queue;
    this.meters = meters;
    meters.gauge("sqs.messages.visible", visible);
    meters.gauge("dlq.count", dlq);
  }

  @Scheduled(fixedDelayString = "10000")
  public void update() {
    try {
      visible.set(count(queue));
      dlq.set(count(queue.replaceFirst("events$", "dlq")));
    } catch (RuntimeException unavailable) {
      meters.counter("consumer.monitor.failures").increment();
    }
  }

  long count(String url) {
    return Long.parseLong(
        sqs.getQueueAttributes(b ->
                b.queueUrl(url).attributeNames(QueueAttributeName.APPROXIMATE_NUMBER_OF_MESSAGES))
            .attributes()
            .getOrDefault(QueueAttributeName.APPROXIMATE_NUMBER_OF_MESSAGES, "0"));
  }
}
