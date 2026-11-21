package io.bankcore.platform;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.*;
import org.springframework.dao.*;
import org.springframework.web.client.*;
import org.slf4j.MDC;
import io.github.resilience4j.circuitbreaker.CallNotPermittedException;

@RestControllerAdvice
public class ApiErrors {
 private static final org.slf4j.Logger log=org.slf4j.LoggerFactory.getLogger(ApiErrors.class);
 public static class Rejected extends RuntimeException {
  public final int status; public final String code;
  public Rejected(int status,String code){super(code);this.status=status;this.code=code;}
 }
 @ExceptionHandler(Rejected.class) ResponseEntity<ProblemDetail> rejected(Rejected e){return problem(e.status,e.code);}
 @ExceptionHandler({IllegalArgumentException.class,ArithmeticException.class,org.springframework.http.converter.HttpMessageNotReadableException.class,org.springframework.web.bind.MissingRequestHeaderException.class,org.springframework.web.method.annotation.MethodArgumentTypeMismatchException.class}) ResponseEntity<ProblemDetail> validation(Exception e){return problem(400,"INVALID_REQUEST");}
 @ExceptionHandler({DataAccessException.class,RestClientException.class,CallNotPermittedException.class}) ResponseEntity<ProblemDetail> unavailable(Exception e){return problem(503,"DEPENDENCY_UNAVAILABLE");}
 @ExceptionHandler(Exception.class) ResponseEntity<ProblemDetail> unexpected(Exception e){log.atError().addKeyValue("action","request_error").addKeyValue("outcome","unexpected").addKeyValue("exception",e.getClass().getSimpleName()).addKeyValue("cause",e.getCause()==null?"none":e.getCause().getClass().getSimpleName()).log("Unhandled request error");return problem(500,"INTERNAL_ERROR");}
 private ResponseEntity<ProblemDetail> problem(int status,String code){var p=ProblemDetail.forStatus(status);p.setTitle(code);p.setProperty("code",code);p.setProperty("correlationId",MDC.get("correlationId"));return ResponseEntity.status(status).body(p);}
}
