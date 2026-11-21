package io.bankcore.ledger;
import org.junit.jupiter.api.Test;import java.math.BigDecimal;import static org.assertj.core.api.Assertions.*;
class MoneyTest {
 @Test void exactScaleAndCurrency(){assertThat(new Money(new BigDecimal("10.00"),"BRL").amount().toPlainString()).isEqualTo("10.00");assertThatThrownBy(()->new Money(new BigDecimal("0.001"),"BRL")).isInstanceOf(ArithmeticException.class);assertThatThrownBy(()->new Money(new BigDecimal("1"),"USD")).isInstanceOf(IllegalArgumentException.class);assertThatThrownBy(()->new Money(BigDecimal.ZERO,"BRL")).isInstanceOf(IllegalArgumentException.class);}
}
