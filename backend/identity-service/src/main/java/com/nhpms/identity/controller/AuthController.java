package com.nhpms.identity.controller;

import com.nhpms.identity.dto.AuthDtos.*; import com.nhpms.identity.entity.User; import com.nhpms.identity.repository.*; import com.nhpms.identity.service.AuthService; import jakarta.validation.Valid; import org.springframework.http.*; import org.springframework.security.core.Authentication; import org.springframework.web.bind.annotation.*; import java.util.*;

@RestController @RequestMapping("/api/v1/auth")
public class AuthController {
 private final AuthService auth; private final UserRepository users; private final UserRoleRepository roles; private final FacilityAccessRepository access;
 public AuthController(AuthService a,UserRepository u,UserRoleRepository r,FacilityAccessRepository f){auth=a;users=u;roles=r;access=f;}
 @PostMapping("/login") public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest request){return ResponseEntity.ok(auth.login(request));}
 @PostMapping("/refresh") public ResponseEntity<LoginResponse> refresh(@Valid @RequestBody RefreshRequest request){return ResponseEntity.ok(auth.refresh(request.refreshToken()));}
 @PostMapping("/logout") public ResponseEntity<Void> logout(@Valid @RequestBody LogoutRequest request){auth.logout(request.refreshToken());return ResponseEntity.noContent().build();}
 @GetMapping("/me") public ResponseEntity<UserResponse> me(Authentication authentication){User u=users.findById(UUID.fromString(authentication.getName())).orElseThrow();return ResponseEntity.ok(new UserResponse(u.getId(),u.getUsername(),u.getEmail(),u.getFirstName(),u.getLastName(),u.getStatus().name()));}
}
