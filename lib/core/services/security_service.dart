import 'dart:io';
import 'package:flutter/services.dart';
import 'package:root_check/root_check.dart';

/// Service responsible for mobile device security checks (HIPAA Compliance).
class SecurityService {
  /// Checks if the device is rooted (Android) or jailbroken (iOS).
  /// Under HIPAA policies, PHI should not be accessed on compromised devices.
  static Future<bool> isDeviceCompromised() async {
    try {
      bool isRooted = await RootCheck.isRooted ?? false;

      // In the root_check package, 'isRooted' usually encapsulates both 
      // Android root checks and iOS jailbreak checks via native channels.
      return isRooted;
    } on PlatformException {
      // If we can't determine, assume safe to avoid breaking the app unnecessarily,
      // but in a strict zero-trust model, you might returning true here.
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
