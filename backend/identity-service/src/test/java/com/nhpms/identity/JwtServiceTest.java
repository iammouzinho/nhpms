package com.nhpms.identity;

import com.nhpms.identity.security.JwtService;
import org.junit.jupiter.api.Test;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;

class JwtServiceTest {
    @Test void createsAndParsesToken() {
        JwtService service = new JwtService("01234567890123456789012345678901", "test", 15);
        String token = service.generate(UUID.randomUUID(), "doctor", List.of("DOCTOR"), List.of(UUID.randomUUID()));
        assertNotNull(token);
        assertEquals("doctor", service.parse(token).getPayload().get("username", String.class));
    }
}
