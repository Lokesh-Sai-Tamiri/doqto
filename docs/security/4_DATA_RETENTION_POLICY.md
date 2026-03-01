# Data Retention and Destruction Policy

**Company Name:** HymnChat
**Effective Date:** [Date]
**Policy Owner:** Security Officer

## 1. Purpose
To establish consistent standards for the retention and secure destruction of data, particularly Protected Health Information (PHI), ensuring compliance with HIPAA and legal requirements.

## 2. Retention Periods
- **Patient Data & Messages (PHI):** Retained as specified by the individual organization's contract, or as mandated by state/federal laws. In the absence of a specific directive, data will be retained for the minimum required operational period.
- **Audit Logs:** Security and access audit logs must be retained for a minimum of six (6) years, as per HIPAA requirements.
- **Ephemeral Messaging:** Even if messages "disappear" from the user interface, the backend system must retain messages in accordance with the organization-specific retention policy and support legal hold workflows.

## 3. Data Archiving Operations
- Data surpassing its active lifecycle will be archived automatically to secure, encrypted, lower-tier storage.
- Storage systems (including audio buckets) must enforce lifecycle management rules.

## 4. Secure Destruction
- **Digital Media:** Cloud vendor secure wipe protocols must be utilized when deleting storage volumes or databases.
- **Data Purging:** Scripts and background jobs will automatically purge data specifically marked for expiration after the retention period lapses, using secure delete practices to prevent recovery.
- **Hardware:** Any physical devices containing internal data must be securely wiped or physically destroyed before disposal.
