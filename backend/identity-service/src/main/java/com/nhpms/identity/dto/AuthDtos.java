package com.nhpms.identity.dto;
import jakarta.validation.constraints.*; import java.util.*;
public final class AuthDtos { private AuthDtos(){}
 public record LoginRequest(@NotBlank String username,@NotBlank String password){}
 public record RefreshRequest(@NotBlank String refreshToken){}
 public record LogoutRequest(@NotBlank String refreshToken){}
 public record LoginResponse(String accessToken,String refreshToken,String tokenType,long expiresIn,UserResponse user,List<String> roles,List<UUID> facilityIds){}
 public record UserResponse(UUID id,String username,String email,String firstName,String lastName,String status){}
 public record CreateUserRequest(@NotBlank String username,@Email String email,@NotBlank @Size(min=8,max=128) String password,@NotBlank String firstName,@NotBlank String lastName,String phone,String employeeNumber,@NotBlank String roleCode,List<UUID> facilityIds){}
}
