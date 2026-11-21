package io.bankcore.projection;
import java.util.*;import java.math.BigDecimal;import org.springframework.web.bind.annotation.*;import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.client.RestClient;import org.springframework.transaction.annotation.Transactional;
@RestController public class ProjectionApi {
 final org.springframework.jdbc.core.JdbcTemplate db;final RestClient http;final String ledger;
 public ProjectionApi(org.springframework.jdbc.core.JdbcTemplate db,RestClient http,@Value("${bankcore.ledger-url}")String ledger){this.db=db;this.http=http;this.ledger=ledger;}
 @GetMapping("/projections/{id}") Map<String,Object> read(@PathVariable UUID id){var rows=db.queryForList("select * from account_projection where account_id=?",id);return rows.isEmpty()?Map.of("account_id",id,"balance",new BigDecimal("0.00"),"currency","BRL"):rows.getFirst();}
 @PostMapping("/internal/reconciliation/{id}") @Transactional public Map<String,Object> reconcile(@PathVariable UUID id){
  var authoritative=http.get().uri(ledger+"/internal/accounts/"+id+"/balance").retrieve().body(Map.class);
  var derived=read(id);BigDecimal expected=new BigDecimal(authoritative.get("balance").toString());BigDecimal actual=new BigDecimal(derived.get("balance").toString());boolean mismatch=expected.compareTo(actual)!=0;
  db.update("insert into reconciliation_audit(account_id,ledger_balance,projection_balance,mismatch) values(?,?,?,?)",id,expected,actual,mismatch);
  return Map.of("accountId",id,"ledgerBalance",expected,"projectionBalance",actual,"mismatchDetected",mismatch);
 }
}
