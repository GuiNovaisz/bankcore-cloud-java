package io.bankcore.account;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;
@EnableScheduling
@SpringBootApplication(scanBasePackages={"io.bankcore.account","io.bankcore.platform"})
public class Application { public static void main(String[] args) { SpringApplication.run(Application.class,args); } }
