package com.nhpms.identity.repository;
import com.nhpms.identity.entity.Role; import org.springframework.data.jpa.repository.JpaRepository; import java.util.*;
public interface RoleRepository extends JpaRepository<Role,UUID>{Optional<Role> findByRoleCode(String roleCode);}
