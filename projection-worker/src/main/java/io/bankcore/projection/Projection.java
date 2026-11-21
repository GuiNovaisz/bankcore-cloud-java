package io.bankcore.projection;

import com.fasterxml.jackson.databind.ObjectMapper;
import java.math.*;
import java.util.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class Projection {
  public record Event(
      UUID eventId,
      String type,
      int schemaVersion,
      UUID source,
      UUID destination,
      String amount,
      String currency) {}

  final JdbcTemplate db;
  final ObjectMapper json;

  public Projection(JdbcTemplate db, ObjectMapper json) {
    this.db = db;
    this.json = json;
  }

  @Transactional
  public void apply(String body) {
    Event e;
    try {
      e = json.readValue(body, Event.class);
    } catch (Exception bad) {
      throw new IllegalArgumentException("INVALID_EVENT");
    }
    if (e.eventId() == null
        || e.source() == null
        || e.destination() == null
        || e.source().equals(e.destination())
        || e.schemaVersion() != 1
        || !"LedgerEntryPosted".equals(e.type())
        || !"BRL".equals(e.currency())) throw new IllegalArgumentException("INVALID_EVENT");
    BigDecimal amount = new BigDecimal(e.amount()).setScale(2, RoundingMode.UNNECESSARY);
    if (amount.signum() <= 0 || amount.precision() > 19)
      throw new IllegalArgumentException("INVALID_AMOUNT");
    int inserted =
        db.update(
            "insert into inbox(event_id,payload) values(?,?) on conflict do nothing",
            e.eventId(),
            body);
    if (inserted == 0) {
      if (!db.queryForObject(
              "select payload from inbox where event_id=?", String.class, e.eventId())
          .equals(body)) throw new IllegalArgumentException("EVENT_ID_COLLISION");
      return;
    }
    // Stable ordering also avoids deadlocks when concurrent consumers apply opposite transfers.
    var deltas = new TreeMap<UUID, BigDecimal>();
    deltas.put(e.source(), amount.negate());
    deltas.put(e.destination(), amount);
    deltas.forEach((id, delta) ->
        db.update(
            "insert into account_projection(account_id,balance,currency) values(?,?,'BRL') on"
                + " conflict(account_id) do update set"
                + " balance=account_projection.balance+excluded.balance",
            id,
            delta));
  }
}
