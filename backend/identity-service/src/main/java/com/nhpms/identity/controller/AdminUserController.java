package com.nhpms.identity.controller;
import com.nhpms.identity.dto.AuthDtos.*; import com.nhpms.identity.entity.User; import com.nhpms.identity.service.AuthService; import jakarta.validation.Valid; import org.springframework.security.access.prepost.PreAuthorize; import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/admin/users") @PreAuthorize("hasAuthority('ROLE_NATIONAL_ADMIN')")
public class AdminUserController { private final AuthService auth; public AdminUserController(AuthService a){auth=a;} @PostMapping public UserResponse create(@Valid @RequestBody CreateUserRequest r){User u=auth.create(r);return new UserResponse(u.getId(),u.getUsername(),u.getEmail(),u.getFirstName(),u.getLastName(),u.getStatus().name());} }
