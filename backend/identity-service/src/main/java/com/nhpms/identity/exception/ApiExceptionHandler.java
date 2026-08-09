package com.nhpms.identity.exception;
import org.springframework.http.*; import org.springframework.web.bind.annotation.*; import java.time.Instant; import java.util.Map;
@RestControllerAdvice
public class ApiExceptionHandler {
 @ExceptionHandler({IllegalArgumentException.class,RuntimeException.class}) ResponseEntity<?> handle(RuntimeException e){return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("timestamp",Instant.now(),"error","AUTHENTICATION_ERROR","message",e.getMessage()==null?"Request failed":e.getMessage()));}
}
