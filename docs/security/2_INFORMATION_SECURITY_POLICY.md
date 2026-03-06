# Information Security Policy

**Company Name:** HymnChat
**Effective Date:** [Date]
**Policy Owner:** Security Officer

## 1. Purpose
The purpose of this Information Security Policy is to establish the framework for protecting the confidentiality, integrity, and availability of HymnChat's information assets, primarily focusing on Protected Health Information (PHI).

## 2. Scope
This policy applies to all systems, networks, facilities, applications (including the iOS and Android mobile apps and backend infrastructure), and personnel (employees, contractors, vendors) that process, store, or transmit PHI.

## 3. Data Classification
All data within HymnChat must be classified into one of the following tiers:
- **Public:** Marketing materials, public APIs.
- **Internal:** Source code, internal business metrics.
- **Confidential/PHI:** Medical records, audio messages containing health data, patient identifiers, and authentication credentials.

## 4. Security Controls Framework
HymnChat adheres to HIPAA Security Rule requirements through the implementation of administrative, physical, and technical safeguards.

### 4.1. Encryption Requirements
- **In Transit:** All communications over external and internal networks must be encrypted using TLS 1.2 or higher. HSTS must be enabled.
- **At Rest:** All databases, storage volumes, and object storage buckets containing PHI (such as audio files) must be encrypted using AES-256.

### 4.2. Mobile App Security
- No PHI will be stored in plain text on local SQLite databases on mobile devices.
- PHI must not be passed through push notification payloads.
- Background crash reporting and analytics must strip all suspected PHI before transmission.

### 4.3. Audit Logging
- Comprehensive audit logs will be maintained for all systems handling PHI.
- Logs will track user access, admin actions, login/logout events, and data modifications.
- Access to audit logs will be strictly controlled and tamper-resistant.

## 5. Policy Review
This policy will be reviewed and updated at least annually by the Security Officer, or following any significant change to the operating environment or regulatory requirements.
