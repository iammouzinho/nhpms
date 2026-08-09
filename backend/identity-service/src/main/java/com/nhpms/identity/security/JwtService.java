package com.nhpms.identity.security;

import io.jsonwebtoken.*; import io.jsonwebtoken.security.Keys; import org.springframework.beans.factory.annotation.Value; import org.springframework.stereotype.Service;
import javax.crypto.SecretKey; import java.nio.charset.StandardCharsets; import java.time.Instant; import java.util.*;

@Service
public class JwtService {
 private final SecretKey key; private final String issuer; private final long minutes;
 public JwtService(@Value("${security.jwt.secret}") String secret,@Value("${security.jwt.issuer}") String issuer,@Value("${security.jwt.access-token-minutes}") long minutes){
   if(secret.length()<32) throw new IllegalStateException("JWT_SECRET must contain at least 32 characters"); this.key=Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8)); this.issuer=issuer; this.minutes=minutes;
 }
 public String generate(UUID userId,String username,List<String> roles,List<UUID> facilities){
   Instant now=Instant.now(); return Jwts.builder().issuer(issuer).subject(userId.toString()).claim("username",username).claim("roles",roles).claim("facilities",facilities.stream().map(UUID::toString).toList()).issuedAt(Date.from(now)).expiration(Date.from(now.plusSeconds(minutes*60))).signWith(key).compact();
 }
 public Jws<Claims> parse(String token){return Jwts.parser().verifyWith(key).requireIssuer(issuer).build().parseSignedClaims(token);}
 public long expiresIn(){return minutes*60;}
}
