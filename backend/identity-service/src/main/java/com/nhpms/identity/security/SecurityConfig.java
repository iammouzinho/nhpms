package com.nhpms.identity.security;

import org.springframework.context.annotation.*; import org.springframework.security.authentication.*; import org.springframework.security.config.annotation.web.builders.HttpSecurity; import org.springframework.security.config.http.SessionCreationPolicy; import org.springframework.security.crypto.argon2.Argon2PasswordEncoder; import org.springframework.security.crypto.password.PasswordEncoder; import org.springframework.security.web.*; import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter; import org.springframework.stereotype.Component; import jakarta.servlet.*; import jakarta.servlet.http.*; import java.io.IOException;

@Configuration
public class SecurityConfig {
 @Bean PasswordEncoder passwordEncoder(){return Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();}
 @Bean SecurityFilterChain securityFilterChain(HttpSecurity http, JwtAuthenticationFilter jwt) throws Exception {return http.csrf(c->c.disable()).sessionManagement(s->s.sessionCreationPolicy(SessionCreationPolicy.STATELESS)).authorizeHttpRequests(a->a.requestMatchers("/api/v1/auth/**","/actuator/health","/error").permitAll().anyRequest().authenticated()).addFilterBefore(jwt,UsernamePasswordAuthenticationFilter.class).build();}
}

@Component
class JwtAuthenticationFilter extends OncePerRequestFilter {
 private final JwtService jwt; JwtAuthenticationFilter(JwtService jwt){this.jwt=jwt;}
 @Override protected void doFilterInternal(HttpServletRequest req,HttpServletResponse res,FilterChain chain)throws ServletException,IOException{
  String h=req.getHeader("Authorization"); if(h!=null&&h.startsWith("Bearer ")){try{var claims=jwt.parse(h.substring(7)).getPayload(); java.util.List<String> roles = claims.get("roles", java.util.List.class); var authorities = roles == null ? List.<org.springframework.security.core.GrantedAuthority>of() : roles.stream().map(r -> (org.springframework.security.core.GrantedAuthority) () -> "ROLE_" + r).toList(); var auth=new UsernamePasswordAuthenticationToken(claims.getSubject(),null,authorities); auth.setDetails(claims); org.springframework.security.core.context.SecurityContextHolder.getContext().setAuthentication(auth);}catch(Exception ignored){}}
  chain.doFilter(req,res);
 }
}
