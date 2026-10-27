package co.edu.ucc.agrovet;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class AgrovetApplication {

    public static void main(String[] args) {
        SpringApplication.run(AgrovetApplication.class, args);
    }
}
