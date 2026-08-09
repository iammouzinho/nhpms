CREATE SCHEMA IF NOT EXISTS iam;

CREATE TABLE iam.users (
    user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username CITEXT NOT NULL UNIQUE,
    email CITEXT UNIQUE,
    password_hash TEXT NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(50),
    employee_number VARCHAR(100),
    status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('PENDING','ACTIVE','LOCKED','DISABLED','EXPIRED')),
    mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    last_login_at TIMESTAMPTZ,
    password_changed_at TIMESTAMPTZ,
    failed_login_count INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE iam.roles (
    role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_code VARCHAR(60) NOT NULL UNIQUE,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    system_role BOOLEAN NOT NULL DEFAULT FALSE,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE iam.permissions (
    permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    permission_code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    resource VARCHAR(100) NOT NULL,
    action VARCHAR(50) NOT NULL,
    description TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE iam.role_permissions (
    role_id UUID NOT NULL REFERENCES iam.roles(role_id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES iam.permissions(permission_id) ON DELETE CASCADE,
    PRIMARY KEY(role_id, permission_id)
);

CREATE TABLE iam.user_roles (
    user_id UUID NOT NULL REFERENCES iam.users(user_id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES iam.roles(role_id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(user_id, role_id)
);

CREATE TABLE iam.user_facility_access (
    user_id UUID NOT NULL REFERENCES iam.users(user_id) ON DELETE CASCADE,
    facility_id UUID NOT NULL,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(user_id, facility_id)
);

CREATE TABLE iam.refresh_tokens (
    refresh_token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES iam.users(user_id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ip_address INET,
    user_agent TEXT
);

CREATE TABLE iam.audit_events (
    audit_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    user_id UUID REFERENCES iam.users(user_id),
    action VARCHAR(80) NOT NULL,
    entity_type VARCHAR(80),
    entity_id UUID,
    outcome VARCHAR(30) NOT NULL DEFAULT 'SUCCESS',
    ip_address INET,
    user_agent TEXT,
    correlation_id UUID,
    metadata JSONB
);

CREATE INDEX idx_iam_refresh_user ON iam.refresh_tokens(user_id);
CREATE INDEX idx_iam_refresh_expiry ON iam.refresh_tokens(expires_at);
CREATE INDEX idx_iam_audit_user_time ON iam.audit_events(user_id, event_time DESC);

INSERT INTO iam.roles(role_code,name,description,system_role) VALUES
('NATIONAL_ADMIN','National Administrator','Full national administration',TRUE),
('HOSPITAL_ADMIN','Hospital Administrator','Hospital administration',TRUE),
('CLINIC_ADMIN','Clinic Administrator','Clinic administration',TRUE),
('DOCTOR','Doctor','Clinical doctor access',TRUE),
('NURSE','Nurse','Nursing access',TRUE),
('RECEPTIONIST','Receptionist','Patient registration and reception',TRUE),
('PHARMACIST','Pharmacist','Pharmacy access',TRUE),
('LAB_TECHNICIAN','Laboratory Technician','Laboratory access',TRUE),
('RADIOLOGY_TECHNICIAN','Radiology Technician','Radiology access',TRUE),
('PATIENT','Patient','Patient self-service access',TRUE)
ON CONFLICT DO NOTHING;

INSERT INTO iam.permissions(permission_code,name,resource,action) VALUES
('USER_READ','Read users','USER','READ'),
('USER_CREATE','Create users','USER','CREATE'),
('USER_UPDATE','Update users','USER','UPDATE'),
('USER_DISABLE','Disable users','USER','DISABLE'),
('ROLE_READ','Read roles','ROLE','READ'),
('FACILITY_ACCESS_MANAGE','Manage facility access','FACILITY_ACCESS','MANAGE'),
('AUDIT_READ','Read audit events','AUDIT','READ')
ON CONFLICT DO NOTHING;
