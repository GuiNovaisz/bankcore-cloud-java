package io.bankcore.account;
import java.util.*;import java.time.Duration;
import org.springframework.web.bind.annotation.*;import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Value;import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;import org.springframework.web.client.RestClient;
import org.springframework.data.redis.core.StringRedisTemplate;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.micrometer.core.instrument.MeterRegistry;
import io.bankcore.platform.ApiErrors.Rejected;

@Service class Accounts {
 final JdbcTemplate db;final RestClient http;final String ledger;final StringRedisTemplate cache;final MeterRegistry meters;
 Accounts(JdbcTemplate db,RestClient http,@Value("${bankcore.ledger-url}")String ledger,StringRedisTemplate cache,MeterRegistry meters){this.db=db;this.http=http;this.ledger=ledger;this.cache=cache;this.meters=meters;}
 Map<String,Object> find(UUID id){var rows=db.queryForList("select * from account where id=?",id);if(rows.isEmpty())throw new Rejected(404,"ACCOUNT_NOT_FOUND");return rows.getFirst();}
 @Transactional public Map<String,Object> create(AccountApi.Create c){
  if(c.id()==null||c.id().toString().equals("00000000-0000-0000-0000-000000000001")||c.ownerReference()==null||!c.ownerReference().matches("[a-zA-Z0-9-]{1,80}"))throw new IllegalArgumentException();
  db.update("insert into account(id,owner_reference,status) values(?,?,'PROVISIONING') on conflict do nothing",c.id(),c.ownerReference());
  var row=db.queryForMap("select * from account where id=? for update",c.id());
  if(!row.get("owner_reference").equals(c.ownerReference()))throw new Rejected(409,"ACCOUNT_CONFLICT");
  if(row.get("status").equals("PROVISIONING")){
   http.post().uri(ledger+"/internal/accounts/"+c.id()).retrieve().toBodilessEntity();
   db.update("update account set status='ACTIVE' where id=?",c.id());invalidate(c.id());
  }return find(c.id());
 }
 @Transactional public Map<String,Object> status(UUID id,String status){
  if(!Set.of("ACTIVE","BLOCKED","CLOSED").contains(status))throw new IllegalArgumentException();
  var rows=db.queryForList("select * from account where id=? for update",id);if(rows.isEmpty())throw new Rejected(404,"ACCOUNT_NOT_FOUND");
  if(rows.getFirst().get("status").equals("CLOSED"))throw new Rejected(409,"ACCOUNT_CLOSED");
  http.put().uri(ledger+"/internal/accounts/"+id+"/gate").body(Map.of("enabled",status.equals("ACTIVE"))).retrieve().toBodilessEntity();
  db.update("update account set status=? where id=?",status,id);invalidate(id);return find(id);
 }
 void invalidate(UUID id){try{cache.delete("account:"+id);}catch(RuntimeException e){meters.counter("cache.requests","result","failure").increment();}}
 public Object cachedRead(UUID id,ObjectMapper json)throws Exception {
  try{String hit=cache.opsForValue().get("account:"+id);if(hit!=null){meters.counter("cache.requests","result","hit").increment();return json.readTree(hit);}}catch(Exception e){meters.counter("cache.requests","result","failure").increment();}
  var row=find(id);meters.counter("cache.requests","result","miss").increment();
  try{cache.opsForValue().set("account:"+id,json.writeValueAsString(row),Duration.ofSeconds(15));}catch(Exception e){meters.counter("cache.requests","result","failure").increment();}return row;
 }
 public List<Map<String,Object>> list(int offset,int limit){if(offset<0||limit<1||limit>100)throw new IllegalArgumentException();return db.queryForList("select * from account order by created_at,id limit ? offset ?",limit,offset);}
}
@RestController public class AccountApi {
 public record Create(UUID id,String ownerReference){} public record State(String status){}
 final Accounts accounts;final ObjectMapper json;
 public AccountApi(Accounts accounts,ObjectMapper json){this.accounts=accounts;this.json=json;}
 @PostMapping("/accounts") Map<String,Object> create(@RequestBody Create c){return accounts.create(c);}
 @PutMapping("/accounts/{id}/status") Map<String,Object> status(@PathVariable UUID id,@RequestBody State state){return accounts.status(id,state.status());}
 @GetMapping("/accounts/{id}") Object read(@PathVariable UUID id)throws Exception {return accounts.cachedRead(id,json);}
 @GetMapping("/internal/accounts/{id}") Map<String,Object> authoritative(@PathVariable UUID id){return accounts.find(id);}
 @GetMapping("/accounts") List<Map<String,Object>> list(@RequestParam(defaultValue="0")int offset,@RequestParam(defaultValue="20")int limit){return accounts.list(offset,limit);}
}
