import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // H4: covers the window while the app is inactive so the task-switcher
  // snapshot never shows PHI.
  private var privacyOverlay: UIVisualEffectView?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // Required by flutter_local_notifications so foreground banners and
    // notification taps are routed to the plugin.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    guard privacyOverlay == nil, let window = self.window else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    blur.frame = window.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(blur)
    privacyOverlay = blur
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
