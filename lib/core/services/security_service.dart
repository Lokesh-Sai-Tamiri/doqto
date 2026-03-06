import 'package:flutter/services.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

/// Service responsible for mobile device security checks (HIPAA Compliance).
class SecurityService {
  /// Checks if the device is rooted (Android) or jailbroken (iOS).
  /// Under HIPAA policies, PHI should not be accessed on compromised devices.
  static Future<bool> isDeviceCompromised() async {
    try {
      return await FlutterJailbreakDetection.jailbroken;
    } on PlatformException {
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Run all startup security checks. Returns a list of failed checks (human readable).
  static Future<List<String>> runStartupChecks() async {
    List<String> failures = [];

    if (await isDeviceCompromised()) {
      failures.add("Device appears to be rooted or jailbroken. For your security, HymnChat cannot run on compromised devices.");
    }

    return failures;
  }
}
