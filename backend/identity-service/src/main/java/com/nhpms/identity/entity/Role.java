package com.nhpms.identity.entity;
import jakarta.persistence.*; import java.util.UUID;
@Entity @Table(name="roles", schema="iam")
public class Role { @Id @GeneratedValue(strategy=GenerationType.UUID) @Column(name="role_id") UUID id; @Column(name="role_code",unique=true,nullable=false) String roleCode; @Column(nullable=false) String name; public UUID getId(){return id;} public String getRoleCode(){return roleCode;} public void setRoleCode(String v){roleCode=v;} public String getName(){return name;} }
