package com.nhpms.identity.service;

import com.nhpms.identity.dto.AuthDtos.*; import com.nhpms.identity.entity.*; import com.nhpms.identity.repository.*; import com.nhpms.identity.security.JwtService; import org.springframework.security.crypto.password.PasswordEncoder; import org.springframework.stereotype.Service; import org.springframework.transaction.annotation.Transactional; import java.nio.charset.StandardCharsets; import java.security.MessageDigest; import java.time.Instant; import java.util.*;

@Service
public class AuthService {
 private static final int MAX_FAILURES=5;
 private final UserRepository users; private final RoleRepository roles; private final UserRoleRepository userRoles; private final FacilityAccessRepository access; private final RefreshTokenRepository refresh; private final PasswordEncoder encoder; private final JwtService jwt;
 public AuthService(UserRepository u,RoleRepository r,UserRoleRepository ur,FacilityAccessRepository a,RefreshTokenRepository rt,PasswordEncoder e,JwtService j){users=u;roles=r;userRoles=ur;access=a;refresh=rt;encoder=e;jwt=j;}
 @Transactional public LoginResponse login(LoginRequest req){
  User u=users.findByUsernameIgnoreCase(req.username()).orElseThrow(()->new RuntimeException("Invalid credentials"));
  if(u.getStatus()!=User.Status.ACTIVE) throw new RuntimeException("Account unavailable");
  if(!encoder.matches(req.password(),u.getPasswordHash())){int n=u.getFailedLoginCount()+1;u.setFailedLoginCount(n);if(n>=MAX_FAILURES)u.setStatus(User.Status.LOCKED);users.save(u);throw new RuntimeException("Invalid credentials");}
  u.setFailedLoginCount(0);u.setLastLoginAt(Instant.now());users.save(u); return issue(u, null, null);
 }
 @Transactional public LoginResponse refresh(String raw){
  RefreshToken old=refresh.findByTokenHash(hash(raw)).orElseThrow(()->new RuntimeException("Invalid refresh token"));
  if(old.getRevokedAt()!=null||old.getExpiresAt().isBefore(Instant.now()))throw new RuntimeException("Refresh token expired or revoked");
  User u=users.findById(old.getUserId()).orElseThrow(()->new RuntimeException("User not found")); old.setRevokedAt(Instant.now());refresh.save(old);return issue(u,null,null);
 }
 @Transactional public void logout(String raw){refresh.findByTokenHash(hash(raw)).ifPresent(t->{t.setRevokedAt(Instant.now());refresh.save(t);});}
 @Transactional public User create(CreateUserRequest r){if(users.existsByUsernameIgnoreCase(r.username()))throw new IllegalArgumentException("Username already exists"); if(r.email()!=null&&users.existsByEmailIgnoreCase(r.email()))throw new IllegalArgumentException("Email already exists"); Role role=roles.findByRoleCode(r.roleCode()).orElseThrow(()->new IllegalArgumentException("Role not found")); User u=new User();u.setUsername(r.username());u.setEmail(r.email());u.setPasswordHash(encoder.encode(r.password()));u.setFirstName(r.firstName());u.setLastName(r.lastName());u.setPhone(r.phone());u.setEmployeeNumber(r.employeeNumber());u.setPasswordChangedAt(Instant.now());u=users.save(u);userRoles.save(new UserRole(u.getId(),role.getId())); if(r.facilityIds()!=null) { boolean first=true; for(UUID facilityId:r.facilityIds()){access.save(new UserFacilityAccess(u.getId(),facilityId,first)); first=false;} } return u;}
 private LoginResponse issue(User u,String ip,String ua){List<UUID> roleIds=userRoles.findRoleIds(u.getId());List<String> roleCodes=roleIds.stream().map(id->roles.findById(id).map(Role::getRoleCode).orElse("UNKNOWN")).toList();List<UUID> facilities=access.findFacilityIds(u.getId());String at=jwt.generate(u.getId(),u.getUsername(),roleCodes,facilities);String raw=UUID.randomUUID()+"."+UUID.randomUUID();RefreshToken rt=new RefreshToken();rt.setUserId(u.getId());rt.setTokenHash(hash(raw));rt.setExpiresAt(Instant.now().plusSeconds(30L*24*3600));rt.setIpAddress(ip);rt.setUserAgent(ua);refresh.save(rt);return new LoginResponse(at,raw,"Bearer",jwt.expiresIn(),new UserResponse(u.getId(),u.getUsername(),u.getEmail(),u.getFirstName(),u.getLastName(),u.getStatus().name()),roleCodes,facilities);}
 private String hash(String value){try{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));}catch(Exception e){throw new IllegalStateException(e);}}
}
