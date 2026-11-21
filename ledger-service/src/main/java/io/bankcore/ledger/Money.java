package io.bankcore.ledger;
import java.math.*;
public record Money(BigDecimal amount,String currency) {
 public Money {
  if(amount==null || !"BRL".equals(currency) || amount.signum()<=0 || amount.precision()>17)throw new IllegalArgumentException("Positive BRL amount required");
  amount=amount.setScale(2,RoundingMode.UNNECESSARY);
 }
}
