package io.bankcore.transfer;

import io.bankcore.platform.ApiErrors.Rejected;
import io.micrometer.core.instrument.MeterRegistry;
import java.math.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class Transfers {
  public record Request(UUID source, UUID destination, BigDecimal amount, String currency) {}

  final JdbcTemplate db;
  final MeterRegistry meters;
  final io.bankcore.platform.TraceSupport traces;

  public Transfers(
      JdbcTemplate db, MeterRegistry meters, io.bankcore.platform.TraceSupport traces) {
    this.db = db;
    this.meters = meters;
    this.traces = traces;
  }

  @Transactional
  public Map<String, Object> create(String key, Request r) {
    if (key == null
        || !key.matches("[a-zA-Z0-9_-]{8,128}")
        || r.source() == null
        || r.destination() == null
        || r.source().equals(r.destination())
        || r.amount() == null
        || r.amount().signum() <= 0
        || r.amount().scale() < -17
        || r.amount().scale() > 100
        || !"BRL".equals(r.currency())) throw new IllegalArgumentException();
    BigDecimal amount = r.amount().setScale(2, RoundingMode.UNNECESSARY);
    if (amount.precision() > 19) throw new IllegalArgumentException("BRL amount exceeds storage range");
    db.update(
        "insert into transfer(id,idempotency_key,source,destination,amount,currency,status)"
            + " values(?,?,?,?,?,?,'REQUESTED') on conflict(idempotency_key) do nothing",
        UUID.randomUUID(),
        key,
        r.source(),
        r.destination(),
        amount,
        r.currency());
    db.update(
        "update transfer set"
            + " traceparent=coalesce(traceparent,?),correlation_id=coalesce(correlation_id,?) where"
            + " idempotency_key=?",
        traces.parent(),
        org.slf4j.MDC.get("correlationId"),
        key);
    var row = db.queryForMap("select * from transfer where idempotency_key=?", key);
    if (!row.get("source").equals(r.source())
        || !row.get("destination").equals(r.destination())
        || ((BigDecimal) row.get("amount")).compareTo(amount) != 0
        || !row.get("currency").equals(r.currency()))
      throw new Rejected(409, "IDEMPOTENCY_CONFLICT");
    meters.counter("transfer.requests").increment();
    return row;
  }

  public Map<String, Object> find(UUID id) {
    var rows = db.queryForList("select * from transfer where id=?", id);
    if (rows.isEmpty()) throw new Rejected(404, "TRANSFER_NOT_FOUND");
    return rows.getFirst();
  }

  public List<Map<String, Object>> list(int offset, int limit) {
    if (offset < 0 || limit < 1 || limit > 100) throw new IllegalArgumentException();
    return db.queryForList(
        "select * from transfer order by created_at,id limit ? offset ?", limit, offset);
  }
}
