package io.bankcore.projection;

import java.net.URI;
import java.time.Duration;
import java.util.*;
import org.slf4j.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.*;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.sqs.SqsClient;

@Configuration
class SqsConfiguration {
  @Bean(destroyMethod = "close")
  SqsClient sqs(
      @Value("${bankcore.sqs-endpoint}") String endpoint,
      @Value("${bankcore.region}") String region) {
    var builder =
        SqsClient.builder()
            .region(Region.of(region))
            .httpClientBuilder(
                UrlConnectionHttpClient.builder()
                    .connectionTimeout(Duration.ofMillis(400))
                    .socketTimeout(Duration.ofSeconds(3)))
            .overrideConfiguration(c ->
                c.apiCallTimeout(Duration.ofSeconds(4))
                    .apiCallAttemptTimeout(Duration.ofSeconds(3))
                    .retryPolicy(r -> r.numRetries(0)));
    if (!endpoint.isBlank()) builder.endpointOverride(URI.create(endpoint));
    return builder.build();
  }
}
