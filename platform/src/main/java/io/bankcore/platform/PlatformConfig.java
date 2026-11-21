package io.bankcore.platform;

import io.github.resilience4j.circuitbreaker.*;
import io.github.resilience4j.micrometer.tagged.TaggedCircuitBreakerMetrics;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import java.net.http.HttpClient;
import java.time.Duration;
import java.util.UUID;
import org.slf4j.MDC;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.*;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.core.userdetails.*;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.provisioning.InMemoryUserDetailsManager;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.client.RestClient;

@Configuration
public class PlatformConfig {
  @Bean
  BCryptPasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder();
  }

  @Bean
  org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer
      decimalStrings() {
    return builder ->
        builder.serializerByType(
            java.math.BigDecimal.class,
            com.fasterxml.jackson.databind.ser.std.ToStringSerializer.instance);
  }

  @Bean
  SecurityFilterChain security(HttpSecurity http) throws Exception {
    return http.csrf(c -> c.disable())
        .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(a ->
            a.requestMatchers("/actuator/health/**")
                .permitAll()
                .requestMatchers("/actuator/prometheus")
                .hasRole("OPERATOR")
                .requestMatchers("/internal/**")
                .hasRole("SERVICE")
                .anyRequest()
                .hasRole("OPERATOR"))
        .httpBasic(b -> {})
        .build();
  }

  @Bean
  UserDetailsService users(
      @Value("${bankcore.operator-password}") String operator,
      @Value("${bankcore.service-password}") String service) {
    if (operator.length() < 24 || service.length() < 24 || operator.equals(service))
      throw new IllegalArgumentException("Distinct passwords of at least 24 characters required");
    var encoder = new BCryptPasswordEncoder();
    return new InMemoryUserDetailsManager(
        User.withUsername("operator").password(encoder.encode(operator)).roles("OPERATOR").build(),
        User.withUsername("service").password(encoder.encode(service)).roles("SERVICE").build());
  }

  @Bean
  RestClient remote(
      RestClient.Builder builder, @Value("${bankcore.service-password}") String secret) {
    var factory =
        new JdkClientHttpRequestFactory(
            HttpClient.newBuilder().connectTimeout(Duration.ofMillis(400)).build());
    factory.setReadTimeout(Duration.ofMillis(900));
    return builder
        .requestFactory(factory)
        .defaultHeaders(h -> h.setBasicAuth("service", secret))
        .requestInterceptor((request, body, execution) -> {
          String id = MDC.get("correlationId");
          if (id != null) request.getHeaders().set("X-Correlation-ID", id);
          return execution.execute(request, body);
        })
        .build();
  }

  @Bean
  CircuitBreakerRegistry breakers(MeterRegistry meters) {
    var config =
        CircuitBreakerConfig.custom()
            .slidingWindowSize(4)
            .minimumNumberOfCalls(4)
            .failureRateThreshold(50)
            .waitDurationInOpenState(Duration.ofSeconds(5))
            .permittedNumberOfCallsInHalfOpenState(2)
            .ignoreExceptions(org.springframework.web.client.HttpClientErrorException.class)
            .build();
    var registry = CircuitBreakerRegistry.of(config);
    TaggedCircuitBreakerMetrics.ofCircuitBreakerRegistry(registry).bindTo(meters);
    return registry;
  }

  @Bean
  FilterRegistrationBean<Filter> correlation() {
    Filter filter =
        new Filter() {
          public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
              throws IOException, ServletException {
            var request = (HttpServletRequest) req;
            var response = (HttpServletResponse) res;
            String id = request.getHeader("X-Correlation-ID");
            if (id == null || !id.matches("[a-zA-Z0-9-]{1,64}")) id = UUID.randomUUID().toString();
            MDC.put("correlationId", id);
            response.setHeader("X-Correlation-ID", id);
            try {
              chain.doFilter(req, res);
            } finally {
              MDC.remove("correlationId");
            }
          }
        };
    var bean = new FilterRegistrationBean<>(filter);
    bean.setOrder(-100);
    return bean;
  }
}
