package io.bankcore.ledger;

import io.bankcore.platform.ApiErrors.Rejected;
import java.util.*;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

@RestController
public class LedgerApi {
  final Ledger ledger;
  final JdbcTemplate db;

  public LedgerApi(Ledger ledger, JdbcTemplate db) {
    this.ledger = ledger;
    this.db = db;
  }

  @PostMapping("/internal/accounts/{id}")
  Map<String, Object> provision(@PathVariable UUID id) {
    if (id.equals(Ledger.TREASURY)) throw new Rejected(403, "RESERVED_ACCOUNT");
    db.update("insert into ledger_account(id) values(?) on conflict do nothing", id);
    return db.queryForMap("select id,currency,enabled from ledger_account where id=?", id);
  }

  public record Gate(boolean enabled) {}

  @PutMapping("/internal/accounts/{id}/gate")
  void gate(@PathVariable UUID id, @RequestBody Gate gate) {
    if (id.equals(Ledger.TREASURY)) throw new Rejected(403, "RESERVED_ACCOUNT");
    if (db.update("update ledger_account set enabled=? where id=?", gate.enabled(), id) != 1)
      throw new Rejected(404, "ACCOUNT_NOT_FOUND");
  }

  @PostMapping("/internal/journals")
  Map<String, Object> post(@RequestBody Ledger.Command c) {
    return ledger.post(c, false);
  }

  @GetMapping("/internal/journals/{id}")
  Map<String, Object> journal(@PathVariable UUID id) {
    var rows = db.queryForList("select * from journal where id=?", id);
    if (rows.isEmpty()) throw new Rejected(404, "JOURNAL_NOT_FOUND");
    return rows.getFirst();
  }

  @GetMapping({"/accounts/{id}/balance", "/internal/accounts/{id}/balance"})
  Map<String, Object> balance(@PathVariable UUID id) {
    var rows = db.queryForList("select id,balance,currency from ledger_account where id=?", id);
    if (rows.isEmpty()) throw new Rejected(404, "ACCOUNT_NOT_FOUND");
    return rows.getFirst();
  }

  @GetMapping("/journals")
  List<Map<String, Object>> journals(
      @RequestParam(defaultValue = "0") int offset, @RequestParam(defaultValue = "20") int limit) {
    if (offset < 0 || limit < 1 || limit > 100) throw new IllegalArgumentException();
    return db.queryForList(
        "select * from journal order by created_at,id limit ? offset ?", limit, offset);
  }

  @PostMapping("/internal/outbox/{id}/replay")
  @org.springframework.transaction.annotation.Transactional
  void replay(@PathVariable UUID id) {
    if (db.update("update outbox set published_at=null,next_attempt_at=now() where id=?", id) != 1)
      throw new Rejected(404, "EVENT_NOT_FOUND");
    db.update("insert into replay_audit(event_id) values(?)", id);
  }
}

@RestController
@Profile("local")
class FundingApi {
  final Ledger ledger;

  FundingApi(Ledger ledger) {
    this.ledger = ledger;
  }

  @PostMapping("/admin/funding")
  Map<String, Object> fund(@RequestBody Ledger.Command c) {
    return ledger.post(
        new Ledger.Command(c.id(), Ledger.TREASURY, c.destination(), c.amount(), c.currency()),
        true);
  }
}
