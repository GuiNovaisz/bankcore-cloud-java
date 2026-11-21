package io.bankcore.transfer;

import java.util.*;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
public class TransferApi {
  final Transfers transfers;

  public TransferApi(Transfers transfers) {
    this.transfers = transfers;
  }

  @PostMapping("/transfers")
  ResponseEntity<Map<String, Object>> create(
      @RequestHeader("Idempotency-Key") String key, @RequestBody Transfers.Request request) {
    return ResponseEntity.accepted().body(transfers.create(key, request));
  }

  @GetMapping("/transfers/{id}")
  Map<String, Object> find(@PathVariable UUID id) {
    return transfers.find(id);
  }

  @GetMapping("/transfers")
  List<Map<String, Object>> list(
      @RequestParam(defaultValue = "0") int offset, @RequestParam(defaultValue = "20") int limit) {
    return transfers.list(offset, limit);
  }
}
