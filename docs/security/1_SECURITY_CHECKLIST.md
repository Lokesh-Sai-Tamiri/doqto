# HymnChat Security & HIPAA Compliance Checklist

## 1️⃣ Governance & Risk Foundation
- [ ] Appoint Security Officer (internal owner)
- [ ] Define HIPAA scope (what systems store/process PHI?)
- [ ] Perform initial HIPAA Risk Assessment
- [ ] Document data flow diagram (end-to-end PHI path)
- [ ] Create Written Security Policies
- [ ] Establish Incident Response Plan
- [ ] Establish Breach Notification Procedure (≤60 days rule)
- [ ] Execute Business Associate Agreements (BAAs) (AWS, GCP, Azure)

## 2️⃣ Infrastructure & Cloud Controls
- [ ] Use HIPAA-eligible services only
- [ ] Separate production, staging, and development environments
- [ ] No real PHI in dev/staging
- [ ] Encrypt all databases (AES-256)
- [ ] Encrypt object storage (audio files)
- [ ] Encrypt backups
- [ ] Enable automatic backup verification
- [ ] Private networking (no public DB exposure)
- [ ] WAF + DDoS protection
- [ ] Centralized logging system
- [ ] Restrict cloud console access (MFA mandatory)
- [ ] Role-based IAM policies (least privilege)

## 3️⃣ Application Security Controls
**Authentication**
- [ ] Unique user IDs (no shared accounts)
- [ ] Strong password requirements
- [ ] MFA for admins (recommended for all users)
- [ ] Account lockout after failed attempts
- [ ] Token expiration and refresh policies
- [ ] Secure session management
**Authorization**
- [ ] Role-Based Access Control (RBAC)
- [ ] Organization-level isolation
- [ ] Data access scoped per tenant
- [ ] Admin privilege separation

## 4️⃣ Encryption Requirements
- [ ] TLS 1.2+ enforced
- [ ] HSTS enabled
- [ ] Certificate pinning (mobile apps)
- [ ] AES-256 encryption at rest
- [ ] End-to-end encryption (recommended for messaging)
- [ ] Secure key management (KMS)
- [ ] Key rotation policy
*Note: Do NOT hardcode encryption keys or store secrets in source code.*

## 5️⃣ Messaging & Audio-Specific Controls
- [ ] Encrypt audio before upload
- [ ] Encrypted storage bucket
- [ ] Time-limited signed URLs
- [ ] No PHI in push notification payload
- [ ] No message previews containing PHI
- [ ] Ephemeral UI does NOT equal deletion
- [ ] Retention policy configurable per organization (Backend retains per policy; support legal hold)

## 6️⃣ Audit Logging
- [ ] Log user login/logout
- [ ] Log message send/receive metadata
- [ ] Log admin actions
- [ ] Log failed login attempts
- [ ] Log PHI access events
- [ ] Tamper-resistant logs
- [ ] Retain logs for required duration (often 6 years)
- [ ] Provide exportable audit reports

## 7️⃣ Data Handling Rules
- [ ] Data classification policy
- [ ] PHI tagging system
- [ ] Data minimization
- [ ] Automatic data purge after retention period
- [ ] Secure deletion processes
- [ ] Backup lifecycle management
*Note: Never send PHI to analytics tools, crash logs, or monitoring dashboards.*

## 8️⃣ Mobile App Security (iOS/Android)
- [ ] Privacy Policy publicly accessible
- [ ] Data Safety form completed (Google Play)
- [ ] App Privacy disclosures completed (Apple)
- [ ] Secure network calls (HTTPS only)
- [ ] Root/jailbreak detection
- [ ] Secure local storage (no plain SQLite PHI)
- [ ] Disable screenshots (Android)
- [ ] Remote wipe capability
- [ ] Device session revocation

## 9️⃣ DevSecOps Controls
- [ ] Secure SDLC process
- [ ] Code reviews mandatory
- [ ] Dependency vulnerability scanning
- [ ] Static Application Security Testing (SAST)
- [ ] Dynamic Application Security Testing (DAST)
- [ ] Container scanning (if applicable)
- [ ] Secrets management system
- [ ] CI/CD with restricted deploy rights
- [ ] No direct production database access

## 🔟 Third-Party Vendor Management
- [ ] Vendor security review
- [ ] Verify HIPAA eligibility
- [ ] Execute BAAs
- [ ] Review subprocessors
- [ ] Annual vendor reassessment
*Careful with: Analytics SDKs, Crash reporting, Push notifications, SMS gateways.*

## 1️⃣1️⃣ Organizational Security
- [ ] Employee HIPAA training
- [ ] Access removal on termination
- [ ] Background checks (recommended)
- [ ] Device security policy
- [ ] Encrypted company laptops
- [ ] Mandatory MFA for internal tools

## 1️⃣2️⃣ Testing & Certification
- [ ] Annual Risk Assessment
- [ ] Annual Penetration Test
- [ ] Remediation tracking
- [ ] SOC 2 Type II roadmap
- [ ] Cyber liability insurance

## 1️⃣3️⃣ Breach Readiness
- [ ] Incident detection process
- [ ] Security monitoring (SIEM recommended)
- [ ] Incident severity classification
- [ ] Legal notification workflow
- [ ] Customer communication templates
- [ ] Forensic investigation plan

## 1️⃣4️⃣ Required Written Documentation
- [ ] Security policies
- [ ] Access control policy
- [ ] Incident response policy
- [ ] Data retention policy
- [ ] Backup policy
- [ ] Risk assessment report
- [ ] Vendor management log
- [ ] Employee training log
