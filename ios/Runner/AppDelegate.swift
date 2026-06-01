import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Register all auto-generated plugins first
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Register the native PDF viewer plugin
    let factory = PdfViewerFactory(messenger: engineBridge.binaryMessenger)
    engineBridge.pluginRegistry.registrar(forPlugin: "PdfViewerPlugin")
      .register(factory, withId: "native_pdf_viewer")
  }
}