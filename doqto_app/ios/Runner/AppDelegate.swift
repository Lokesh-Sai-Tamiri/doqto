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
    // Under the UIScene lifecycle the applicationWillResignActive /
    // applicationDidBecomeActive delegate callbacks never fire — UIApplication
    // still posts the equivalent notifications, so H4 hangs off those instead.
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(coverForPrivacy),
      name: UIApplication.willResignActiveNotification, object: nil)
    center.addObserver(
      self, selector: #selector(uncoverForPrivacy),
      name: UIApplication.didBecomeActiveNotification, object: nil)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// self.window is nil under the scene lifecycle; the scene owns the window.
  private var activeWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow } ?? self.window
  }

  @objc private func coverForPrivacy() {
    guard privacyOverlay == nil, let window = activeWindow else { return }
    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
    blur.frame = window.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    window.addSubview(blur)
    privacyOverlay = blur
  }

  @objc private func uncoverForPrivacy() {
    privacyOverlay?.removeFromSuperview()
    privacyOverlay = nil
  }
}
