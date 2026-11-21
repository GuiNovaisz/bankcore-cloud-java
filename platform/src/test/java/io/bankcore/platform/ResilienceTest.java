package io.bankcore.platform;

import com.sun.net.httpserver.HttpServer;
import io.github.resilience4j.circuitbreaker.*;
import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.web.client.RestClient;
import java.net.InetSocketAddress;
import java.time.Duration;
import java.util.concurrent.*;
import static org.assertj.core.api.Assertions.*;
import static org.awaitility.Awaitility.await;

class ResilienceTest {
 @Test void actualRemoteClientHasBoundedTimeout() throws Exception {
  var entered=new CountDownLatch(1);var release=new CountDownLatch(1);
  var server=HttpServer.create(new InetSocketAddress("127.0.0.1",0),0);
  server.createContext("/slow",exchange->{entered.countDown();try{release.await(5,TimeUnit.SECONDS);}catch(InterruptedException e){Thread.currentThread().interrupt();}finally{exchange.close();}});
  server.start();
  try {
   var client=new PlatformConfig().remote(RestClient.builder(),"non-sensitive-test-only-password");
   long start=System.nanoTime();
   assertThatThrownBy(()->client.get().uri("http://127.0.0.1:"+server.getAddress().getPort()+"/slow").retrieve().toBodilessEntity()).isInstanceOf(org.springframework.web.client.ResourceAccessException.class);
   assertThat(entered.await(1,TimeUnit.SECONDS)).isTrue();
   assertThat(Duration.ofNanos(System.nanoTime()-start)).isLessThan(Duration.ofSeconds(3));
  } finally {release.countDown();server.stop(0);}
 }
 @Test void productionBreakerOpensFailsFastAndRecovers() {
  var cb=new PlatformConfig().breakers(new SimpleMeterRegistry()).circuitBreaker("account");
  for(int i=0;i<4;i++)assertThatThrownBy(()->cb.executeSupplier(()->{throw new IllegalStateException("dependency down");})).isInstanceOf(IllegalStateException.class);
  assertThat(cb.getState()).isEqualTo(CircuitBreaker.State.OPEN);
  assertThatThrownBy(()->cb.executeSupplier(()->"unexpected")).isInstanceOf(CallNotPermittedException.class);
  var transitions=new CopyOnWriteArrayList<String>();
  cb.getEventPublisher().onStateTransition(e->transitions.add(e.getStateTransition().toString()));
  await().atMost(Duration.ofSeconds(8)).pollInterval(Duration.ofMillis(100)).untilAsserted(()->assertThatCode(()->cb.executeSupplier(()->"healthy")).doesNotThrowAnyException());
  assertThat(cb.getState()).isEqualTo(CircuitBreaker.State.HALF_OPEN);
  assertThat(cb.executeSupplier(()->"healthy")).isEqualTo("healthy");
  assertThat(cb.getState()).isEqualTo(CircuitBreaker.State.CLOSED);
  assertThat(transitions).contains("State transition from OPEN to HALF_OPEN","State transition from HALF_OPEN to CLOSED");
 }
}
