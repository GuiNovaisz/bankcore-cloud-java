package io.bankcore.platform;
import org.springframework.stereotype.Component;import io.micrometer.tracing.*;import org.slf4j.MDC;
@Component public class TraceSupport {
 final Tracer tracer;public TraceSupport(Tracer tracer){this.tracer=tracer;}
 public String parent(){var s=tracer.currentSpan();return s==null?null:"00-"+s.context().traceId()+"-"+s.context().spanId()+"-01";}
 public void run(String parent,String correlation,String name,Runnable action){
  Span span;
  if(parent!=null&&parent.matches("00-[0-9a-f]{32}-[0-9a-f]{16}-0[01]")){
   var parts=parent.split("-");var context=tracer.traceContextBuilder().traceId(parts[1]).spanId(parts[2]).sampled(parts[3].equals("01")).build();span=tracer.spanBuilder().setParent(context).name(name).start();
  }else span=tracer.nextSpan().name(name).start();
  String previous=MDC.get("correlationId");if(correlation!=null)MDC.put("correlationId",correlation);
  try(var scope=tracer.withSpan(span)){action.run();}catch(RuntimeException e){span.error(e);throw e;}finally{span.end();if(previous==null)MDC.remove("correlationId");else MDC.put("correlationId",previous);}
 }
}
