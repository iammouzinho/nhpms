package com.nhpms.identity.repository;
import com.nhpms.identity.entity.UserFacilityAccess; import org.springframework.data.jpa.repository.*; import java.util.*;
public interface FacilityAccessRepository extends JpaRepository<UserFacilityAccess,UserFacilityAccess.Key>{@Query("select a.facilityId from UserFacilityAccess a where a.userId=:userId") List<UUID> findFacilityIds(UUID userId);}
