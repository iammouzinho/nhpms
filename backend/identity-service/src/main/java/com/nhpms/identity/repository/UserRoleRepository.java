package com.nhpms.identity.repository;
import com.nhpms.identity.entity.UserRole; import org.springframework.data.jpa.repository.*; import java.util.*;
public interface UserRoleRepository extends JpaRepository<UserRole,UserRole.Key>{@Query("select ur.roleId from UserRole ur where ur.userId=:userId") List<UUID> findRoleIds(UUID userId);}
