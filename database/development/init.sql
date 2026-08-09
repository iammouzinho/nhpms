-- NHPMS - National Healthcare Patient Management System
-- PostgreSQL 16+
-- Single PostgreSQL database organized into bounded-context schemas.
-- For strict database-per-microservice deployment, split schemas later.
-- Never store raw facial images here; store provider references and/or encrypted templates.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

BEGIN;

CREATE SCHEMA IF NOT EXISTS reference_data;
CREATE SCHEMA IF NOT EXISTS organization;
CREATE SCHEMA IF NOT EXISTS iam;
CREATE SCHEMA IF NOT EXISTS patient;
CREATE SCHEMA IF NOT EXISTS clinical;
CREATE SCHEMA IF NOT EXISTS pharmacy;
CREATE SCHEMA IF NOT EXISTS transfer;
CREATE SCHEMA IF NOT EXISTS files;
CREATE SCHEMA IF NOT EXISTS notification;
CREATE SCHEMA IF NOT EXISTS integration;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS reporting;

CREATE OR REPLACE FUNCTION public.set_updated_at() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = CURRENT_TIMESTAMP; RETURN NEW; END $$;

-- ============================================================
-- REFERENCE DATA
-- ============================================================
CREATE TABLE reference_data.countries (
 country_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), iso2_code CHAR(2) NOT NULL UNIQUE,
 iso3_code CHAR(3) NOT NULL UNIQUE, country_name VARCHAR(120) NOT NULL UNIQUE, active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE reference_data.provinces (
 province_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), country_id UUID NOT NULL REFERENCES reference_data.countries(country_id),
 code VARCHAR(20) NOT NULL, name VARCHAR(120) NOT NULL, active BOOLEAN NOT NULL DEFAULT TRUE,
 UNIQUE(country_id,code), UNIQUE(country_id,name)
);
CREATE TABLE reference_data.districts (
 district_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), province_id UUID NOT NULL REFERENCES reference_data.provinces(province_id),
 code VARCHAR(20) NOT NULL, name VARCHAR(120) NOT NULL, active BOOLEAN NOT NULL DEFAULT TRUE,
 UNIQUE(province_id,code), UNIQUE(province_id,name)
);
CREATE TABLE reference_data.genders (gender_code VARCHAR(30) PRIMARY KEY, description VARCHAR(100) NOT NULL, active BOOLEAN NOT NULL DEFAULT TRUE);
CREATE TABLE reference_data.blood_groups (blood_group_code VARCHAR(10) PRIMARY KEY, description VARCHAR(50) NOT NULL);
CREATE TABLE reference_data.marital_statuses (marital_status_code VARCHAR(30) PRIMARY KEY, description VARCHAR(100) NOT NULL);
CREATE TABLE reference_data.languages (language_code VARCHAR(10) PRIMARY KEY, name VARCHAR(100) NOT NULL);
CREATE TABLE reference_data.medication_routes (route_code VARCHAR(30) PRIMARY KEY, description VARCHAR(100) NOT NULL);
CREATE TABLE reference_data.units_of_measure (unit_code VARCHAR(30) PRIMARY KEY, description VARCHAR(100) NOT NULL);
CREATE TABLE reference_data.allergy_types (allergy_type_code VARCHAR(30) PRIMARY KEY, description VARCHAR(100) NOT NULL);
CREATE TABLE reference_data.allergy_severities (severity_code VARCHAR(30) PRIMARY KEY, description VARCHAR(100) NOT NULL);
CREATE TABLE reference_data.encounter_types (encounter_type_code VARCHAR(40) PRIMARY KEY, description VARCHAR(120) NOT NULL);
CREATE TABLE reference_data.admission_types (admission_type_code VARCHAR(40) PRIMARY KEY, description VARCHAR(120) NOT NULL);
CREATE TABLE reference_data.diagnosis_types (diagnosis_type_code VARCHAR(40) PRIMARY KEY, description VARCHAR(120) NOT NULL);
CREATE TABLE reference_data.document_types (document_type_code VARCHAR(40) PRIMARY KEY, description VARCHAR(120) NOT NULL);
CREATE TABLE reference_data.prescription_statuses (status_code VARCHAR(30) PRIMARY KEY, description VARCHAR(100) NOT NULL);
CREATE TABLE reference_data.transfer_statuses (status_code VARCHAR(30) PRIMARY KEY, description VARCHAR(100) NOT NULL);

-- ============================================================
-- ORGANIZATION / TENANCY
-- ============================================================
CREATE TABLE organization.organizations (
 organization_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), parent_id UUID REFERENCES organization.organizations(organization_id),
 organization_code VARCHAR(50) NOT NULL UNIQUE, legal_name VARCHAR(255) NOT NULL, display_name VARCHAR(255) NOT NULL,
 organization_type VARCHAR(40) NOT NULL CHECK(organization_type IN ('NATIONAL','REGIONAL','HOSPITAL','CLINIC','PHARMACY','LABORATORY','RADIOLOGY','OTHER')),
 tax_number VARCHAR(100), phone VARCHAR(50), email CITEXT, address_line1 VARCHAR(255), address_line2 VARCHAR(255),
 district_id UUID REFERENCES reference_data.districts(district_id), postal_code VARCHAR(30), active BOOLEAN NOT NULL DEFAULT TRUE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE organization.facilities (
 facility_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), organization_id UUID NOT NULL REFERENCES organization.organizations(organization_id),
 facility_code VARCHAR(50) NOT NULL, name VARCHAR(255) NOT NULL,
 facility_type VARCHAR(30) NOT NULL CHECK(facility_type IN ('HOSPITAL','CLINIC','PHARMACY','LABORATORY','RADIOLOGY','OTHER')),
 phone VARCHAR(50), email CITEXT, address_line1 VARCHAR(255), district_id UUID REFERENCES reference_data.districts(district_id),
 latitude NUMERIC(10,7), longitude NUMERIC(10,7), active BOOLEAN NOT NULL DEFAULT TRUE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(organization_id,facility_code)
);
CREATE TABLE organization.departments (
 department_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL REFERENCES organization.facilities(facility_id),
 department_code VARCHAR(50) NOT NULL, name VARCHAR(150) NOT NULL, department_type VARCHAR(50), active BOOLEAN NOT NULL DEFAULT TRUE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(facility_id,department_code)
);
CREATE TABLE organization.wards (
 ward_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), department_id UUID NOT NULL REFERENCES organization.departments(department_id),
 ward_code VARCHAR(50) NOT NULL, name VARCHAR(150) NOT NULL, gender_restriction VARCHAR(20), active BOOLEAN NOT NULL DEFAULT TRUE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(department_id,ward_code)
);
CREATE TABLE organization.rooms (
 room_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), ward_id UUID NOT NULL REFERENCES organization.wards(ward_id),
 room_number VARCHAR(50) NOT NULL, room_type VARCHAR(40) NOT NULL CHECK(room_type IN ('GENERAL','PRIVATE','ICU','EMERGENCY','OPERATING','MATERNITY','ISOLATION','OTHER')),
 floor_number VARCHAR(20), capacity INTEGER NOT NULL DEFAULT 1 CHECK(capacity>0), active BOOLEAN NOT NULL DEFAULT TRUE,
 UNIQUE(ward_id,room_number)
);
CREATE TABLE organization.beds (
 bed_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), room_id UUID NOT NULL REFERENCES organization.rooms(room_id),
 bed_number VARCHAR(50) NOT NULL, bed_status VARCHAR(30) NOT NULL DEFAULT 'AVAILABLE' CHECK(bed_status IN ('AVAILABLE','OCCUPIED','RESERVED','MAINTENANCE','OUT_OF_SERVICE')),
 active BOOLEAN NOT NULL DEFAULT TRUE, UNIQUE(room_id,bed_number)
);

-- ============================================================
-- IAM / RBAC
-- ============================================================
CREATE TABLE iam.users (
 user_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), username CITEXT NOT NULL UNIQUE, email CITEXT UNIQUE,
 password_hash TEXT NOT NULL, first_name VARCHAR(100) NOT NULL, middle_name VARCHAR(100), last_name VARCHAR(100) NOT NULL,
 phone VARCHAR(50), employee_number VARCHAR(100), status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('PENDING','ACTIVE','LOCKED','DISABLED','EXPIRED')),
 mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE, last_login_at TIMESTAMPTZ, password_changed_at TIMESTAMPTZ,
 failed_login_count INTEGER NOT NULL DEFAULT 0, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE iam.roles (
 role_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), role_code VARCHAR(60) NOT NULL UNIQUE, name VARCHAR(120) NOT NULL,
 description TEXT, system_role BOOLEAN NOT NULL DEFAULT FALSE, active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE iam.permissions (
 permission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), permission_code VARCHAR(100) NOT NULL UNIQUE, name VARCHAR(150) NOT NULL,
 resource VARCHAR(100) NOT NULL, action VARCHAR(50) NOT NULL, description TEXT, active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE iam.role_permissions (
 role_id UUID NOT NULL REFERENCES iam.roles(role_id) ON DELETE CASCADE, permission_id UUID NOT NULL REFERENCES iam.permissions(permission_id) ON DELETE CASCADE,
 PRIMARY KEY(role_id,permission_id)
);
CREATE TABLE iam.user_roles (
 user_id UUID NOT NULL REFERENCES iam.users(user_id) ON DELETE CASCADE, role_id UUID NOT NULL REFERENCES iam.roles(role_id) ON DELETE CASCADE,
 assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(user_id,role_id)
);
CREATE TABLE iam.user_facility_access (
 user_id UUID NOT NULL REFERENCES iam.users(user_id) ON DELETE CASCADE, facility_id UUID NOT NULL REFERENCES organization.facilities(facility_id) ON DELETE CASCADE,
 is_primary BOOLEAN NOT NULL DEFAULT FALSE, assigned_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY(user_id,facility_id)
);
CREATE TABLE iam.refresh_tokens (
 refresh_token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES iam.users(user_id) ON DELETE CASCADE,
 token_hash TEXT NOT NULL UNIQUE, expires_at TIMESTAMPTZ NOT NULL, revoked_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 ip_address INET, user_agent TEXT
);
CREATE TABLE iam.mfa_methods (
 mfa_method_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES iam.users(user_id) ON DELETE CASCADE,
 method_type VARCHAR(30) NOT NULL CHECK(method_type IN ('TOTP','SMS','EMAIL')), secret_encrypted BYTEA, destination VARCHAR(255),
 active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- PATIENT
-- ============================================================
CREATE TABLE patient.patients (
 patient_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_number VARCHAR(50) NOT NULL UNIQUE,
 first_name VARCHAR(100) NOT NULL, middle_name VARCHAR(100), last_name VARCHAR(100) NOT NULL, preferred_name VARCHAR(100),
 date_of_birth DATE, gender_code VARCHAR(30) REFERENCES reference_data.genders(gender_code), blood_group_code VARCHAR(10) REFERENCES reference_data.blood_groups(blood_group_code),
 marital_status_code VARCHAR(30) REFERENCES reference_data.marital_statuses(marital_status_code), nationality_country_id UUID REFERENCES reference_data.countries(country_id),
 preferred_language_code VARCHAR(10) REFERENCES reference_data.languages(language_code), phone VARCHAR(50), alternate_phone VARCHAR(50), email CITEXT,
 occupation VARCHAR(150), address_line1 VARCHAR(255), address_line2 VARCHAR(255), district_id UUID REFERENCES reference_data.districts(district_id),
 emergency_flag BOOLEAN NOT NULL DEFAULT FALSE, deceased BOOLEAN NOT NULL DEFAULT FALSE, deceased_at TIMESTAMPTZ, deceased_reason TEXT,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','INACTIVE','DECEASED','MERGED','DUPLICATE')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, version BIGINT NOT NULL DEFAULT 0
);
CREATE TABLE patient.patient_identifiers (
 patient_identifier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES patient.patients(patient_id) ON DELETE CASCADE,
 identifier_type VARCHAR(40) NOT NULL, identifier_value VARCHAR(255) NOT NULL, issuing_country_id UUID REFERENCES reference_data.countries(country_id),
 issuing_authority VARCHAR(255), issue_date DATE, expiry_date DATE, is_primary BOOLEAN NOT NULL DEFAULT FALSE, verified BOOLEAN NOT NULL DEFAULT FALSE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(identifier_type,identifier_value)
);
CREATE TABLE patient.patient_contacts (
 contact_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES patient.patients(patient_id) ON DELETE CASCADE,
 contact_type VARCHAR(30) NOT NULL CHECK(contact_type IN ('EMERGENCY','NEXT_OF_KIN','GUARDIAN')), full_name VARCHAR(255) NOT NULL,
 relationship VARCHAR(100), phone VARCHAR(50), alternate_phone VARCHAR(50), email CITEXT, address TEXT, is_primary BOOLEAN NOT NULL DEFAULT FALSE
);
CREATE TABLE patient.patient_allergies (
 allergy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES patient.patients(patient_id) ON DELETE CASCADE,
 allergy_type_code VARCHAR(30) REFERENCES reference_data.allergy_types(allergy_type_code), allergen VARCHAR(255) NOT NULL,
 severity_code VARCHAR(30) REFERENCES reference_data.allergy_severities(severity_code), reaction TEXT, notes TEXT, active BOOLEAN NOT NULL DEFAULT TRUE,
 recorded_by UUID REFERENCES iam.users(user_id), recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE patient.patient_conditions (
 condition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES patient.patients(patient_id) ON DELETE CASCADE,
 condition_code VARCHAR(100), condition_name VARCHAR(255) NOT NULL, onset_date DATE, resolved_date DATE,
 status VARCHAR(30) NOT NULL DEFAULT 'ACTIVE' CHECK(status IN ('ACTIVE','RESOLVED','INACTIVE')), notes TEXT,
 recorded_by UUID REFERENCES iam.users(user_id), created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE patient.patient_biometrics (
 biometric_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES patient.patients(patient_id) ON DELETE CASCADE,
 provider_name VARCHAR(100) NOT NULL, provider_subject_id VARCHAR(255) NOT NULL, biometric_type VARCHAR(30) NOT NULL DEFAULT 'FACE',
 encrypted_template BYTEA, template_algorithm VARCHAR(100), template_version VARCHAR(50), consent_obtained BOOLEAN NOT NULL DEFAULT FALSE,
 consent_at TIMESTAMPTZ, active BOOLEAN NOT NULL DEFAULT TRUE, enrolled_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, revoked_at TIMESTAMPTZ,
 UNIQUE(provider_name,provider_subject_id)
);
CREATE TABLE patient.patient_consents (
 consent_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES patient.patients(patient_id) ON DELETE CASCADE,
 consent_type VARCHAR(60) NOT NULL, consent_version VARCHAR(30) NOT NULL, granted BOOLEAN NOT NULL, granted_at TIMESTAMPTZ, revoked_at TIMESTAMPTZ,
 captured_by UUID REFERENCES iam.users(user_id), evidence_file_id UUID, notes TEXT
);
CREATE TABLE patient.patient_merges (
 merge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), source_patient_id UUID NOT NULL REFERENCES patient.patients(patient_id),
 target_patient_id UUID NOT NULL REFERENCES patient.patients(patient_id), reason TEXT NOT NULL, merged_by UUID REFERENCES iam.users(user_id),
 merged_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, CHECK(source_patient_id<>target_patient_id)
);

-- ============================================================
-- CLINICAL
-- ============================================================
CREATE TABLE clinical.admissions (
 admission_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES patient.patients(patient_id),
 facility_id UUID NOT NULL REFERENCES organization.facilities(facility_id), department_id UUID REFERENCES organization.departments(department_id),
 ward_id UUID REFERENCES organization.wards(ward_id), room_id UUID REFERENCES organization.rooms(room_id), bed_id UUID REFERENCES organization.beds(bed_id),
 admission_type_code VARCHAR(40) REFERENCES reference_data.admission_types(admission_type_code), admission_number VARCHAR(60) NOT NULL UNIQUE,
 admitted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, expected_discharge_at TIMESTAMPTZ, discharged_at TIMESTAMPTZ,
 admission_reason TEXT, condition_on_entry TEXT, admission_status VARCHAR(30) NOT NULL DEFAULT 'ADMITTED' CHECK(admission_status IN ('PENDING','ADMITTED','TRANSFERRED','DISCHARGED','CANCELLED')),
 admitted_by UUID REFERENCES iam.users(user_id), discharged_by UUID REFERENCES iam.users(user_id), discharge_summary TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE clinical.encounters (
 encounter_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES patient.patients(patient_id), admission_id UUID REFERENCES clinical.admissions(admission_id),
 facility_id UUID NOT NULL REFERENCES organization.facilities(facility_id), department_id UUID REFERENCES organization.departments(department_id),
 encounter_type_code VARCHAR(40) REFERENCES reference_data.encounter_types(encounter_type_code), encounter_number VARCHAR(60) NOT NULL UNIQUE,
 started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, ended_at TIMESTAMPTZ, attending_user_id UUID REFERENCES iam.users(user_id),
 status VARCHAR(30) NOT NULL DEFAULT 'OPEN' CHECK(status IN ('OPEN','CLOSED','CANCELLED')), chief_complaint TEXT, notes TEXT,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE clinical.vital_signs (
 vital_sign_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
 recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, recorded_by UUID REFERENCES iam.users(user_id), temperature NUMERIC(5,2), pulse_rate INTEGER,
 respiratory_rate INTEGER, systolic_bp INTEGER, diastolic_bp INTEGER, oxygen_saturation NUMERIC(5,2), weight_kg NUMERIC(7,2), height_cm NUMERIC(7,2),
 blood_glucose NUMERIC(8,2), notes TEXT
);
CREATE TABLE clinical.consultations (
 consultation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
 doctor_user_id UUID NOT NULL REFERENCES iam.users(user_id), consultation_type VARCHAR(50), consultation_date TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 history_of_present_illness TEXT, physical_examination TEXT, assessment TEXT, plan TEXT,
 status VARCHAR(30) NOT NULL DEFAULT 'COMPLETED' CHECK(status IN ('DRAFT','COMPLETED','AMENDED','CANCELLED')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE clinical.diagnoses (
 diagnosis_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
 consultation_id UUID REFERENCES clinical.consultations(consultation_id), diagnosis_code VARCHAR(50), diagnosis_name VARCHAR(255) NOT NULL,
 diagnosis_type_code VARCHAR(40) REFERENCES reference_data.diagnosis_types(diagnosis_type_code), diagnosed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 diagnosed_by UUID REFERENCES iam.users(user_id), notes TEXT
);
CREATE TABLE clinical.clinical_notes (
 note_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id) ON DELETE CASCADE,
 author_user_id UUID NOT NULL REFERENCES iam.users(user_id), note_type VARCHAR(50) NOT NULL, note_text TEXT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, amended_at TIMESTAMPTZ
);
CREATE TABLE clinical.procedures (
 procedure_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id),
 procedure_code VARCHAR(60), procedure_name VARCHAR(255) NOT NULL, performed_at TIMESTAMPTZ, performed_by UUID REFERENCES iam.users(user_id), outcome TEXT, notes TEXT
);
CREATE TABLE clinical.laboratory_requests (
 laboratory_request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id), requested_by UUID REFERENCES iam.users(user_id),
 external_reference VARCHAR(100), priority VARCHAR(30) NOT NULL DEFAULT 'ROUTINE', requested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 status VARCHAR(30) NOT NULL DEFAULT 'REQUESTED' CHECK(status IN ('REQUESTED','COLLECTED','PROCESSING','COMPLETED','CANCELLED')), clinical_notes TEXT
);
CREATE TABLE clinical.laboratory_items (
 laboratory_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), laboratory_request_id UUID NOT NULL REFERENCES clinical.laboratory_requests(laboratory_request_id) ON DELETE CASCADE,
 test_code VARCHAR(60), test_name VARCHAR(255) NOT NULL, specimen_type VARCHAR(100), result_value TEXT, result_unit VARCHAR(50), reference_range VARCHAR(100),
 abnormal_flag VARCHAR(20), result_at TIMESTAMPTZ, verified_by UUID REFERENCES iam.users(user_id)
);
CREATE TABLE clinical.imaging_requests (
 imaging_request_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), encounter_id UUID NOT NULL REFERENCES clinical.encounters(encounter_id), requested_by UUID REFERENCES iam.users(user_id),
 modality VARCHAR(50) NOT NULL, body_part VARCHAR(255), clinical_indication TEXT, priority VARCHAR(30) NOT NULL DEFAULT 'ROUTINE',
 requested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, status VARCHAR(30) NOT NULL DEFAULT 'REQUESTED' CHECK(status IN ('REQUESTED','SCHEDULED','IN_PROGRESS','COMPLETED','CANCELLED')),
 report_text TEXT, reported_at TIMESTAMPTZ
);
CREATE TABLE clinical.admission_daily_assessments (
 assessment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), admission_id UUID NOT NULL REFERENCES clinical.admissions(admission_id) ON DELETE CASCADE,
 assessment_date DATE NOT NULL, assessed_by UUID NOT NULL REFERENCES iam.users(user_id), general_condition TEXT, symptoms TEXT, progress_notes TEXT,
 treatment_response TEXT, next_plan TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(admission_id,assessment_date)
);
CREATE TABLE clinical.discharges (
 discharge_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), admission_id UUID NOT NULL UNIQUE REFERENCES clinical.admissions(admission_id),
 discharged_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, discharge_type VARCHAR(40) NOT NULL CHECK(discharge_type IN ('NORMAL','TRANSFER','LAMA','DECEASED','OTHER')),
 discharge_condition TEXT, diagnosis_summary TEXT, treatment_summary TEXT, medication_summary TEXT, follow_up_instructions TEXT, discharged_by UUID REFERENCES iam.users(user_id)
);

-- ============================================================
-- PHARMACY
-- ============================================================
CREATE TABLE pharmacy.medications (
 medication_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), medication_code VARCHAR(80) NOT NULL UNIQUE, generic_name VARCHAR(255) NOT NULL,
 brand_name VARCHAR(255), strength VARCHAR(100), dosage_form VARCHAR(100), route_code VARCHAR(30) REFERENCES reference_data.medication_routes(route_code),
 unit_code VARCHAR(30) REFERENCES reference_data.units_of_measure(unit_code), controlled BOOLEAN NOT NULL DEFAULT FALSE, active BOOLEAN NOT NULL DEFAULT TRUE,
 created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE pharmacy.pharmacies (
 pharmacy_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), facility_id UUID NOT NULL UNIQUE REFERENCES organization.facilities(facility_id), license_number VARCHAR(100), active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE pharmacy.prescriptions (
 prescription_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), prescription_code VARCHAR(80) NOT NULL UNIQUE, patient_id UUID NOT NULL REFERENCES patient.patients(patient_id),
 encounter_id UUID REFERENCES clinical.encounters(encounter_id), prescribing_doctor_id UUID REFERENCES iam.users(user_id), facility_id UUID NOT NULL REFERENCES organization.facilities(facility_id),
 issued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, valid_until TIMESTAMPTZ, status_code VARCHAR(30) NOT NULL DEFAULT 'ACTIVE' REFERENCES reference_data.prescription_statuses(status_code),
 notes TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE pharmacy.prescription_items (
 prescription_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), prescription_id UUID NOT NULL REFERENCES pharmacy.prescriptions(prescription_id) ON DELETE CASCADE,
 medication_id UUID NOT NULL REFERENCES pharmacy.medications(medication_id), quantity_prescribed NUMERIC(12,2) NOT NULL CHECK(quantity_prescribed>0), dosage VARCHAR(100) NOT NULL,
 frequency VARCHAR(100) NOT NULL, route_code VARCHAR(30) REFERENCES reference_data.medication_routes(route_code), duration_value INTEGER, duration_unit VARCHAR(30), instructions TEXT,
 remaining_quantity NUMERIC(12,2) NOT NULL CHECK(remaining_quantity>=0), UNIQUE(prescription_id,medication_id)
);
CREATE TABLE pharmacy.prescription_access_tokens (
 access_token_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), prescription_id UUID NOT NULL REFERENCES pharmacy.prescriptions(prescription_id) ON DELETE CASCADE,
 token_hash TEXT NOT NULL UNIQUE, qr_payload_hash TEXT UNIQUE, expires_at TIMESTAMPTZ NOT NULL, revoked_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE pharmacy.dispensings (
 dispensing_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), prescription_id UUID NOT NULL REFERENCES pharmacy.prescriptions(prescription_id), pharmacy_id UUID NOT NULL REFERENCES pharmacy.pharmacies(pharmacy_id),
 pharmacist_user_id UUID REFERENCES iam.users(user_id), dispensed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 dispensing_status VARCHAR(30) NOT NULL DEFAULT 'COMPLETED' CHECK(dispensing_status IN ('PARTIAL','COMPLETED','CANCELLED')), notes TEXT
);
CREATE TABLE pharmacy.dispensing_items (
 dispensing_item_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), dispensing_id UUID NOT NULL REFERENCES pharmacy.dispensings(dispensing_id) ON DELETE CASCADE,
 prescription_item_id UUID NOT NULL REFERENCES pharmacy.prescription_items(prescription_item_id), quantity_dispensed NUMERIC(12,2) NOT NULL CHECK(quantity_dispensed>0), batch_number VARCHAR(100), expiry_date DATE, instructions_given TEXT
);
CREATE TABLE pharmacy.medication_inventory (
 inventory_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), pharmacy_id UUID NOT NULL REFERENCES pharmacy.pharmacies(pharmacy_id), medication_id UUID NOT NULL REFERENCES pharmacy.medications(medication_id),
 batch_number VARCHAR(100) NOT NULL, expiry_date DATE, quantity_on_hand NUMERIC(14,2) NOT NULL DEFAULT 0, reorder_level NUMERIC(14,2) NOT NULL DEFAULT 0,
 updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, UNIQUE(pharmacy_id,medication_id,batch_number)
);

-- ============================================================
-- TRANSFERS
-- ============================================================
CREATE TABLE transfer.patient_transfers (
 transfer_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), transfer_number VARCHAR(80) NOT NULL UNIQUE, patient_id UUID NOT NULL REFERENCES patient.patients(patient_id),
 source_facility_id UUID NOT NULL REFERENCES organization.facilities(facility_id), destination_facility_id UUID NOT NULL REFERENCES organization.facilities(facility_id),
 source_admission_id UUID REFERENCES clinical.admissions(admission_id), reason TEXT NOT NULL, clinical_summary TEXT, requested_by UUID REFERENCES iam.users(user_id),
 approved_by UUID REFERENCES iam.users(user_id), accepted_by UUID REFERENCES iam.users(user_id), requested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 approved_at TIMESTAMPTZ, accepted_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, status_code VARCHAR(30) NOT NULL DEFAULT 'REQUESTED' REFERENCES reference_data.transfer_statuses(status_code),
 rejection_reason TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, CHECK(source_facility_id<>destination_facility_id)
);
CREATE TABLE transfer.transfer_documents (
 transfer_document_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), transfer_id UUID NOT NULL REFERENCES transfer.patient_transfers(transfer_id) ON DELETE CASCADE,
 file_id UUID, document_type VARCHAR(50) NOT NULL, description TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE transfer.transfer_events (
 transfer_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), transfer_id UUID NOT NULL REFERENCES transfer.patient_transfers(transfer_id) ON DELETE CASCADE,
 event_type VARCHAR(50) NOT NULL, event_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, facility_id UUID REFERENCES organization.facilities(facility_id), user_id UUID REFERENCES iam.users(user_id), notes TEXT
);

-- ============================================================
-- FILES
-- ============================================================
CREATE TABLE files.files (
 file_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), owner_patient_id UUID REFERENCES patient.patients(patient_id), facility_id UUID REFERENCES organization.facilities(facility_id),
 uploaded_by UUID REFERENCES iam.users(user_id), document_type_code VARCHAR(40) REFERENCES reference_data.document_types(document_type_code), file_name VARCHAR(255) NOT NULL,
 storage_provider VARCHAR(50) NOT NULL DEFAULT 'MINIO', bucket_name VARCHAR(255) NOT NULL, object_key VARCHAR(1000) NOT NULL, mime_type VARCHAR(150),
 file_size_bytes BIGINT CHECK(file_size_bytes>=0), sha256_hash VARCHAR(64), encrypted BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(storage_provider,bucket_name,object_key)
);
CREATE TABLE files.file_links (
 file_link_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), file_id UUID NOT NULL REFERENCES files.files(file_id) ON DELETE CASCADE,
 entity_type VARCHAR(80) NOT NULL, entity_id UUID NOT NULL, link_type VARCHAR(50), created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(file_id,entity_type,entity_id)
);
ALTER TABLE patient.patient_consents ADD CONSTRAINT fk_consent_file FOREIGN KEY(evidence_file_id) REFERENCES files.files(file_id);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
CREATE TABLE notification.notifications (
 notification_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID REFERENCES patient.patients(patient_id), user_id UUID REFERENCES iam.users(user_id),
 facility_id UUID REFERENCES organization.facilities(facility_id), notification_type VARCHAR(40) NOT NULL, channel VARCHAR(30) NOT NULL CHECK(channel IN ('PUSH','SMS','EMAIL','IN_APP')),
 subject VARCHAR(255), message TEXT NOT NULL, status VARCHAR(30) NOT NULL DEFAULT 'PENDING' CHECK(status IN ('PENDING','SENT','FAILED','READ','CANCELLED')),
 scheduled_at TIMESTAMPTZ, sent_at TIMESTAMPTZ, read_at TIMESTAMPTZ, provider_message_id VARCHAR(255), failure_reason TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- INTEGRATION
-- ============================================================
CREATE TABLE integration.external_systems (
 external_system_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), system_code VARCHAR(80) NOT NULL UNIQUE, system_name VARCHAR(255) NOT NULL,
 system_type VARCHAR(50), base_url TEXT, active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE integration.external_identifiers (
 external_identifier_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), external_system_id UUID NOT NULL REFERENCES integration.external_systems(external_system_id),
 entity_type VARCHAR(80) NOT NULL, entity_id UUID NOT NULL, external_id VARCHAR(255) NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(external_system_id,entity_type,external_id)
);
CREATE TABLE integration.integration_messages (
 integration_message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), external_system_id UUID REFERENCES integration.external_systems(external_system_id), message_type VARCHAR(100) NOT NULL,
 direction VARCHAR(20) NOT NULL CHECK(direction IN ('INBOUND','OUTBOUND')), correlation_id UUID, idempotency_key VARCHAR(255), payload_hash VARCHAR(128),
 status VARCHAR(30) NOT NULL DEFAULT 'RECEIVED' CHECK(status IN ('RECEIVED','PROCESSING','PROCESSED','FAILED','RETRYING')), received_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 processed_at TIMESTAMPTZ, retry_count INTEGER NOT NULL DEFAULT 0, error_message TEXT, UNIQUE(idempotency_key)
);

-- ============================================================
-- AUDIT / COMPLIANCE
-- ============================================================
CREATE TABLE audit.audit_events (
 audit_event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), event_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, user_id UUID REFERENCES iam.users(user_id),
 facility_id UUID REFERENCES organization.facilities(facility_id), patient_id UUID REFERENCES patient.patients(patient_id), action VARCHAR(80) NOT NULL,
 entity_type VARCHAR(80), entity_id UUID, outcome VARCHAR(30) NOT NULL DEFAULT 'SUCCESS', ip_address INET, user_agent TEXT, correlation_id UUID,
 old_values JSONB, new_values JSONB, metadata JSONB
);
CREATE TABLE audit.patient_access_log (
 access_log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES patient.patients(patient_id), user_id UUID REFERENCES iam.users(user_id),
 facility_id UUID REFERENCES organization.facilities(facility_id), access_type VARCHAR(50) NOT NULL, purpose VARCHAR(255), accessed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 ip_address INET, correlation_id UUID
);

-- ============================================================
-- REPORTING
-- ============================================================
CREATE TABLE reporting.report_definitions (
 report_definition_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), report_code VARCHAR(80) NOT NULL UNIQUE, report_name VARCHAR(255) NOT NULL,
 description TEXT, report_type VARCHAR(50) NOT NULL, active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE reporting.report_jobs (
 report_job_id UUID PRIMARY KEY DEFAULT gen_random_uuid(), report_definition_id UUID NOT NULL REFERENCES reporting.report_definitions(report_definition_id), requested_by UUID REFERENCES iam.users(user_id),
 facility_id UUID REFERENCES organization.facilities(facility_id), parameters JSONB, status VARCHAR(30) NOT NULL DEFAULT 'QUEUED' CHECK(status IN ('QUEUED','RUNNING','COMPLETED','FAILED')),
 output_file_id UUID REFERENCES files.files(file_id), requested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, completed_at TIMESTAMPTZ, error_message TEXT
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_facilities_org ON organization.facilities(organization_id);
CREATE INDEX idx_departments_facility ON organization.departments(facility_id);
CREATE INDEX idx_wards_department ON organization.wards(department_id);
CREATE INDEX idx_rooms_ward ON organization.rooms(ward_id);
CREATE INDEX idx_beds_room ON organization.beds(room_id);
CREATE INDEX idx_user_roles_role ON iam.user_roles(role_id);
CREATE INDEX idx_user_facility_access_facility ON iam.user_facility_access(facility_id);
CREATE INDEX idx_refresh_tokens_user ON iam.refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expiry ON iam.refresh_tokens(expires_at);
CREATE INDEX idx_patient_name ON patient.patients(last_name,first_name);
CREATE INDEX idx_patient_dob ON patient.patients(date_of_birth);
CREATE INDEX idx_patient_phone ON patient.patients(phone);
CREATE INDEX idx_patient_identifiers_patient ON patient.patient_identifiers(patient_id);
CREATE INDEX idx_patient_allergies_patient ON patient.patient_allergies(patient_id);
CREATE INDEX idx_patient_conditions_patient ON patient.patient_conditions(patient_id);
CREATE INDEX idx_patient_biometrics_patient ON patient.patient_biometrics(patient_id);
CREATE INDEX idx_admissions_patient ON clinical.admissions(patient_id);
CREATE INDEX idx_admissions_facility_status ON clinical.admissions(facility_id,admission_status);
CREATE INDEX idx_admissions_dates ON clinical.admissions(admitted_at,discharged_at);
CREATE INDEX idx_encounters_patient ON clinical.encounters(patient_id);
CREATE INDEX idx_encounters_admission ON clinical.encounters(admission_id);
CREATE INDEX idx_encounters_facility_date ON clinical.encounters(facility_id,started_at);
CREATE INDEX idx_vitals_encounter ON clinical.vital_signs(encounter_id);
CREATE INDEX idx_consultations_encounter ON clinical.consultations(encounter_id);
CREATE INDEX idx_diagnoses_encounter ON clinical.diagnoses(encounter_id);
CREATE INDEX idx_lab_requests_encounter ON clinical.laboratory_requests(encounter_id);
CREATE INDEX idx_imaging_requests_encounter ON clinical.imaging_requests(encounter_id);
CREATE INDEX idx_daily_assessment_admission ON clinical.admission_daily_assessments(admission_id);
CREATE INDEX idx_prescriptions_patient ON pharmacy.prescriptions(patient_id);
CREATE INDEX idx_prescriptions_facility_status ON pharmacy.prescriptions(facility_id,status_code);
CREATE INDEX idx_prescription_items_prescription ON pharmacy.prescription_items(prescription_id);
CREATE INDEX idx_dispensings_prescription ON pharmacy.dispensings(prescription_id);
CREATE INDEX idx_dispensings_pharmacy ON pharmacy.dispensings(pharmacy_id);
CREATE INDEX idx_inventory_pharmacy_medication ON pharmacy.medication_inventory(pharmacy_id,medication_id);
CREATE INDEX idx_transfers_patient ON transfer.patient_transfers(patient_id);
CREATE INDEX idx_transfers_source ON transfer.patient_transfers(source_facility_id);
CREATE INDEX idx_transfers_destination ON transfer.patient_transfers(destination_facility_id);
CREATE INDEX idx_transfers_status ON transfer.patient_transfers(status_code);
CREATE INDEX idx_files_patient ON files.files(owner_patient_id);
CREATE INDEX idx_files_facility ON files.files(facility_id);
CREATE INDEX idx_file_links_entity ON files.file_links(entity_type,entity_id);
CREATE INDEX idx_notifications_patient ON notification.notifications(patient_id);
CREATE INDEX idx_notifications_user ON notification.notifications(user_id);
CREATE INDEX idx_notifications_status ON notification.notifications(status);
CREATE INDEX idx_integration_messages_status ON integration.integration_messages(status);
CREATE INDEX idx_integration_messages_correlation ON integration.integration_messages(correlation_id);
CREATE INDEX idx_audit_user_time ON audit.audit_events(user_id,event_time DESC);
CREATE INDEX idx_audit_patient_time ON audit.audit_events(patient_id,event_time DESC);
CREATE INDEX idx_audit_entity ON audit.audit_events(entity_type,entity_id);
CREATE INDEX idx_patient_access_patient_time ON audit.patient_access_log(patient_id,accessed_at DESC);

-- ============================================================
-- UPDATED_AT TRIGGERS
-- ============================================================
CREATE TRIGGER trg_org_updated BEFORE UPDATE ON organization.organizations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_facility_updated BEFORE UPDATE ON organization.facilities FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_department_updated BEFORE UPDATE ON organization.departments FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_user_updated BEFORE UPDATE ON iam.users FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_patient_updated BEFORE UPDATE ON patient.patients FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_admission_updated BEFORE UPDATE ON clinical.admissions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_encounter_updated BEFORE UPDATE ON clinical.encounters FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_consultation_updated BEFORE UPDATE ON clinical.consultations FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_prescription_updated BEFORE UPDATE ON pharmacy.prescriptions FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();
CREATE TRIGGER trg_inventory_updated BEFORE UPDATE ON pharmacy.medication_inventory FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================
-- INITIAL REFERENCE DATA
-- ============================================================
INSERT INTO reference_data.genders VALUES ('MALE','Male',TRUE),('FEMALE','Female',TRUE),('OTHER','Other',TRUE),('UNKNOWN','Unknown',TRUE) ON CONFLICT DO NOTHING;
INSERT INTO reference_data.blood_groups VALUES ('A+','A Positive'),('A-','A Negative'),('B+','B Positive'),('B-','B Negative'),('AB+','AB Positive'),('AB-','AB Negative'),('O+','O Positive'),('O-','O Negative'),('UNKNOWN','Unknown') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.marital_statuses VALUES ('SINGLE','Single'),('MARRIED','Married'),('DIVORCED','Divorced'),('WIDOWED','Widowed'),('UNKNOWN','Unknown') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.languages VALUES ('pt','Portuguese'),('en','English') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.medication_routes VALUES ('ORAL','Oral'),('IV','Intravenous'),('IM','Intramuscular'),('SC','Subcutaneous'),('TOPICAL','Topical'),('INHALATION','Inhalation'),('RECTAL','Rectal'),('OTHER','Other') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.prescription_statuses VALUES ('ACTIVE','Active'),('PARTIALLY_DISPENSED','Partially Dispensed'),('DISPENSED','Dispensed'),('EXPIRED','Expired'),('CANCELLED','Cancelled') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.transfer_statuses VALUES ('REQUESTED','Requested'),('APPROVED','Approved'),('REJECTED','Rejected'),('ACCEPTED','Accepted'),('IN_TRANSIT','In Transit'),('COMPLETED','Completed'),('CANCELLED','Cancelled') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.encounter_types VALUES ('OUTPATIENT','Outpatient'),('INPATIENT','Inpatient'),('EMERGENCY','Emergency'),('FOLLOW_UP','Follow-up'),('TELEMEDICINE','Telemedicine') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.admission_types VALUES ('EMERGENCY','Emergency'),('ELECTIVE','Elective'),('REFERRAL','Referral'),('TRANSFER','Transfer'),('MATERNITY','Maternity') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.diagnosis_types VALUES ('PRIMARY','Primary'),('SECONDARY','Secondary'),('PROVISIONAL','Provisional'),('FINAL','Final') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.allergy_types VALUES ('MEDICATION','Medication'),('FOOD','Food'),('ENVIRONMENTAL','Environmental'),('OTHER','Other') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.allergy_severities VALUES ('MILD','Mild'),('MODERATE','Moderate'),('SEVERE','Severe'),('LIFE_THREATENING','Life Threatening') ON CONFLICT DO NOTHING;
INSERT INTO reference_data.document_types VALUES ('ID_DOCUMENT','Identification Document'),('CONSENT','Consent'),('LAB_RESULT','Laboratory Result'),('IMAGING_RESULT','Imaging Result'),('DISCHARGE_SUMMARY','Discharge Summary'),('TRANSFER_DOCUMENT','Transfer Document'),('PRESCRIPTION','Prescription'),('OTHER','Other') ON CONFLICT DO NOTHING;
INSERT INTO iam.roles(role_code,name,description,system_role) VALUES
('NATIONAL_ADMIN','National Administrator','Full national administration',TRUE),('HOSPITAL_ADMIN','Hospital Administrator','Hospital administration',TRUE),
('CLINIC_ADMIN','Clinic Administrator','Clinic administration',TRUE),('DOCTOR','Doctor','Clinical doctor access',TRUE),('NURSE','Nurse','Nursing access',TRUE),
('RECEPTIONIST','Receptionist','Patient registration and reception',TRUE),('PHARMACIST','Pharmacist','Pharmacy and dispensing access',TRUE),
('LAB_TECHNICIAN','Laboratory Technician','Laboratory access',TRUE),('RADIOLOGY_TECHNICIAN','Radiology Technician','Radiology access',TRUE),('PATIENT','Patient','Patient self-service access',TRUE)
ON CONFLICT DO NOTHING;

COMMIT;

-- ============================================================
-- PRODUCTION HARDENING TO ADD BEFORE GO-LIVE
-- ============================================================
-- * PostgreSQL roles per service and least-privilege GRANTs
-- * Row Level Security (RLS) based on facility/tenant context
-- * Partition large audit/access/event tables by date
-- * KMS/HSM-backed encryption for biometric material
-- * PITR + encrypted backups + tested restore procedures
-- * ICD-10/ICD-11 and ATC medication reference catalogs
-- * Outbox/event tables for reliable RabbitMQ publication
-- * Service-specific databases when moving from MVP to strict microservices
-- * Avoid cross-service foreign keys after database-per-service split
