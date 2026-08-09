package com.nhpms.identity.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name="users", schema="iam")
public class User {
    @Id @GeneratedValue(strategy=GenerationType.UUID) @Column(name="user_id") private UUID id;
    @Column(nullable=false, unique=true) private String username;
    private String email;
    @Column(name="password_hash", nullable=false) private String passwordHash;
    @Column(name="first_name", nullable=false) private String firstName;
    @Column(name="middle_name") private String middleName;
    @Column(name="last_name", nullable=false) private String lastName;
    private String phone;
    @Column(name="employee_number") private String employeeNumber;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private Status status = Status.ACTIVE;
    @Column(name="mfa_enabled", nullable=false) private boolean mfaEnabled;
    @Column(name="last_login_at") private Instant lastLoginAt;
    @Column(name="password_changed_at") private Instant passwordChangedAt;
    @Column(name="failed_login_count", nullable=false) private int failedLoginCount;
    @Column(name="created_at", nullable=false, updatable=false) private Instant createdAt = Instant.now();
    @Column(name="updated_at", nullable=false) private Instant updatedAt = Instant.now();

    public enum Status { PENDING, ACTIVE, LOCKED, DISABLED, EXPIRED }
    @PreUpdate void touch(){ updatedAt=Instant.now(); }
    public UUID getId(){return id;} public String getUsername(){return username;} public void setUsername(String v){username=v;}
    public String getEmail(){return email;} public void setEmail(String v){email=v;}
    public String getPasswordHash(){return passwordHash;} public void setPasswordHash(String v){passwordHash=v;}
    public String getFirstName(){return firstName;} public void setFirstName(String v){firstName=v;}
    public String getMiddleName(){return middleName;} public void setMiddleName(String v){middleName=v;}
    public String getLastName(){return lastName;} public void setLastName(String v){lastName=v;}
    public String getPhone(){return phone;} public void setPhone(String v){phone=v;}
    public String getEmployeeNumber(){return employeeNumber;} public void setEmployeeNumber(String v){employeeNumber=v;}
    public Status getStatus(){return status;} public void setStatus(Status v){status=v;}
    public boolean isMfaEnabled(){return mfaEnabled;} public void setMfaEnabled(boolean v){mfaEnabled=v;}
    public Instant getLastLoginAt(){return lastLoginAt;} public void setLastLoginAt(Instant v){lastLoginAt=v;}
    public Instant getPasswordChangedAt(){return passwordChangedAt;} public void setPasswordChangedAt(Instant v){passwordChangedAt=v;}
    public int getFailedLoginCount(){return failedLoginCount;} public void setFailedLoginCount(int v){failedLoginCount=v;}
}
