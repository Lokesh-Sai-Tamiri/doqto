# Apple Support Case — ITMS-90111 on compliant binaries

**Where to file:** App Store Connect > Contact Us > App Review / App Store Connect
(https://developer.apple.com/contact/topic/select) — category "App Store Connect,
uploading and processing builds". Reference the app and submission IDs below.

---

**Subject:** ITMS-90111 incorrectly rejecting binaries built with current release
Xcode 26.6 (17F113) — six consecutive automated rejections

**App:** Doqto — Apple ID 6802418904, bundle com.doqto.doqtoApp, team GBM6D48UJZ
**Version:** 1.0.0, builds 7, 8, 9, 10, 11
**Submission IDs:** 9cedd95e-7a37-426e-9db8-9ed73ec3144a (builds 7-11) and the
new submission created Aug 25, 2026 ~1:50 AM PT (build 11)

Every submission is automatically rejected with ITMS-90111 ("Unsupported SDK or
Xcode version — App submissions must use the latest Xcode and SDK Release
Candidates") within approximately one minute, at: Aug 19 4:35 AM, Aug 24 11:43 PM,
Aug 25 12:57 AM, 1:24 AM, 1:45 AM, and 1:50 AM (2026).

Builds 8-11 were built with **Xcode 26.6 (17F113)** — the current general
release — against the **iOS 26.5 SDK (23F81a)** that Xcode 26.6 ships, meeting
the published minimum (Xcode 26 / iOS 26 SDK, developer.apple.com/news/upcoming-requirements).
No Xcode 27 RC exists (newest is beta 6, 27A5252f).

Verified in the rejected build 11 binary (1.0.0 (11), uploaded Aug 25 ~1:33 AM PT):
- Info.plist: DTXcode 2660, DTXcodeBuild 17F113, DTSDKName iphoneos26.5,
  DTPlatformVersion 26.5, BuildMachineOSBuild 25G83 — in the app and all 28
  nested bundle Info.plists (frameworks + resource bundles)
- Mach-O LC_BUILD_VERSION: sdk 26.5 on the main executable and all 19 embedded
  frameworks (verified with otool -l)
- Asset catalog: "Xcode 26.6 (17F113)" (verified with assetutil --info)
- Signed Apple Distribution, App Store Connect distribution profile,
  get-task-allow false; codesign --verify --deep --strict passes

Five successive binaries progressively eliminated every version stamp the
validator could inspect; the rejection is unchanged and instant each time,
including on a brand-new submission. Please check why the automated validation
is failing this app, or advise what unpublished requirement the binary fails.
