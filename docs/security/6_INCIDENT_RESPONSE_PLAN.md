# Incident Response Plan

**Company Name:** HymnChat
**Effective Date:** [Date]
**Policy Owner:** Security Officer

## 1. Purpose
To define the organizational approach for detecting, managing, and recovering from security incidents, particularly those involving a potential breach of Protected Health Information (PHI).

## 2. Incident Classification
Incidents are classified by severity:
- **Low:** Anomalous activity with no evidence of compromise (e.g., failed brute-force attempt).
- **Medium:** Compromise of an individual user account with limited impact.
- **High/Critical:** Confirmed or highly suspected unauthorized access to server infrastructure, databases, or systemic compromise of PHI.

## 3. Incident Response Team
The Core Incident Response Team includes:
- Security Officer (Lead)
- CTO / Lead Engineer
- Legal / Compliance Advisor

## 4. Response Phases
1. **Detection & Reporting:** All employees must report suspicious activity. SIEM or logging systems will trigger alerts for anomalies.
2. **Containment:** The team will take immediate steps to isolate compromised systems, revoke active sessions, block IP addresses, or take infrastructure offline if necessary.
3. **Eradication:** Artifacts, malware, or unauthorized access vectors are removed, and vulnerabilities are patched.
4. **Recovery:** Systems are safely restored from clean backups, and passwords/keys are rotated.
5. **Post-Incident Activity:** A post-mortem report will be generated detailing the timeline, impact, and lessons learned.

## 5. Breach Notification Procedure
In the event of a confirmed breach involving unsecured PHI:
- Affected individuals and clients (Covered Entities) must be notified without unreasonable delay and **in no case later than 60 days** following the discovery of the breach.
- If the breach affects 500 or more individuals, the Secretary of HHS and prominent media outlets must also be notified within the 60-day window.
- Notification templates and communication workflows will be coordinated with the legal advisor.
