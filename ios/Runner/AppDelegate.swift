import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register the native Vision-framework text recognition channel.
    let controller = window?.rootViewController as! FlutterViewController
    TextRecognitionPlugin.register(
      with: self.registrar(forPlugin: "TextRecognitionPlugin")!
    )

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
