# Vendor Management Log

**Company Name:** HymnChat
**Maintained By:** Security Officer

This log tracks all third-party vendors and subprocessors that interact with HymnChat's infrastructure or may process Protected Health Information (PHI). **Under HIPAA, a valid Business Associate Agreement (BAA) must be executed with all eligible vendors.**

| Vendor Name | Service Provided | Handles PHI? | HIPAA Eligible? | BAA Executed (Date) | Last Security Review | Next Assessment Due | Notes |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---|
| Amazon Web Services (AWS) | Cloud Hosting, DB, S3 | Yes | Yes | [Date] | [Date] | [Date] | Ensure all used AWS services are covered in their HIPAA eligible list. |
| Google Cloud Platform (GCP) | Hosting / ML services | Yes | Yes | [Date] | [Date] | [Date] | |
| Firebase | Push Notifications | No | Yes | [Date] | [Date] | [Date] | Confirm PHI is blocked from push payloads. |
| Sentry | Crash Reporting | No | No | N/A | [Date] | [Date] | Data scrubbing must be active to drop all PHI. |
| [Analytics SDK] | App Analytics | No | No | N/A | [Date] | [Date] | Never send user identifiable info or PHI to analytics. |

### Subprocessor Review Guidelines:
- Prior to onboarding any new software, SDK, or cloud service, the Security Officer must perform a review.
- Any service capable of receiving PHI must sign a BAA.
- Vendors must be reassessed annually for compliance posture and security incidents.
