package com.nhpms.identity.repository;
import com.nhpms.identity.entity.User; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface UserRepository extends JpaRepository<User,UUID> { Optional<User> findByUsernameIgnoreCase(String username); boolean existsByUsernameIgnoreCase(String username); boolean existsByEmailIgnoreCase(String email); }
