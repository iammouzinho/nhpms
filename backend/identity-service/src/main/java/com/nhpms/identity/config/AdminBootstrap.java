package com.nhpms.identity.config;

import com.nhpms.identity.entity.User;
import com.nhpms.identity.entity.Role;
import com.nhpms.identity.entity.UserRole;
import com.nhpms.identity.repository.RoleRepository;
import com.nhpms.identity.repository.UserRepository;
import com.nhpms.identity.repository.UserRoleRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;

@Configuration
public class AdminBootstrap {
    @Bean
    CommandLineRunner createInitialAdmin(
            UserRepository users,
            RoleRepository roles,
            UserRoleRepository userRoles,
            PasswordEncoder encoder,
            @Value("${NHPMS_ADMIN_USERNAME:}") String username,
            @Value("${NHPMS_ADMIN_PASSWORD:}") String password) {
        return args -> {
            if (username == null || username.isBlank() || password == null || password.isBlank()) return;
            if (users.existsByUsernameIgnoreCase(username)) return;
            if (password.length() < 12) throw new IllegalStateException("NHPMS_ADMIN_PASSWORD must have at least 12 characters");

            Role role = roles.findByRoleCode("NATIONAL_ADMIN")
                    .orElseThrow(() -> new IllegalStateException("NATIONAL_ADMIN role was not seeded"));
            User admin = new User();
            admin.setUsername(username);
            admin.setPasswordHash(encoder.encode(password));
            admin.setFirstName("System");
            admin.setLastName("Administrator");
            admin.setStatus(User.Status.ACTIVE);
            admin.setPasswordChangedAt(Instant.now());
            admin = users.save(admin);
            userRoles.save(new UserRole(admin.getId(), role.getId()));
        };
    }
}
