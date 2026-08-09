package com.nhpms.identity.repository;
import org.springframework.data.jpa.repository.*; import java.util.*; import com.nhpms.identity.entity.RefreshToken;
public interface RefreshTokenRepository extends JpaRepository<RefreshToken,UUID>{Optional<RefreshToken> findByTokenHash(String hash);}
