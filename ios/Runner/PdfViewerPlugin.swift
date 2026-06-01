import Flutter
import UIKit
import PDFKit

// MARK: - Factory
class PdfViewerFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
    }

    func create(withFrame frame: CGRect,
                viewIdentifier viewId: Int64,
                arguments args: Any?) -> FlutterPlatformView {
        return PdfNativeView(frame: frame, args: args, messenger: messenger, viewId: viewId)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - Native View
class PdfNativeView: NSObject, FlutterPlatformView {
    private var pdfView: PDFView
    private var channel: FlutterMethodChannel?

    init(frame: CGRect, args: Any?, messenger: FlutterBinaryMessenger, viewId: Int64) {
        pdfView = PDFView(frame: frame)
        super.init()

        let params = args as? [String: Any]
        let filePath = params?["filePath"] as? String ?? ""
        let initialPage = params?["initialPage"] as? Int ?? 0
        let isDark = params?["isDark"] as? Bool ?? false

        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        // Initial theme setup
        setTheme(isDark: isDark)

        if let url = URL(string: "file://\(filePath)"),
           let doc = PDFDocument(url: url) {
            pdfView.document = doc
            if let page = doc.page(at: initialPage) {
                pdfView.go(to: page)
            }
        }
        
        setupMethodChannel(messenger: messenger, viewId: viewId)
    }
    
    private func setTheme(isDark: Bool) {
        if isDark {
            pdfView.backgroundColor = UIColor(red: 18/255.0, green: 18/255.0, blue: 18/255.0, alpha: 1.0)
        } else {
            pdfView.backgroundColor = UIColor(red: 245/255.0, green: 245/255.0, blue: 245/255.0, alpha: 1.0)
        }
    }
    
    private func setupMethodChannel(messenger: FlutterBinaryMessenger, viewId: Int64) {
        channel = FlutterMethodChannel(name: "pdf_viewer/control/\(viewId)", binaryMessenger: messenger)
        channel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            guard let self = self else { return }
            
            switch call.method {
            case "setDarkMode":
                if let args = call.arguments as? [String: Any],
                   let isDark = args["isDark"] as? Bool {
                    self.setTheme(isDark: isDark)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "isDark missing", details: nil))
                }
            case "jumpToPage":
                if let args = call.arguments as? [String: Any],
                   let pageIndex = args["page"] as? Int,
                   let doc = self.pdfView.document,
                   let page = doc.page(at: pageIndex) {
                    self.pdfView.go(to: page)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "page missing or invalid", details: nil))
                }
            case "getPageCount":
                result(self.pdfView.document?.pageCount ?? 0)
            case "getCurrentPage":
                if let doc = self.pdfView.document,
                   let currentPage = self.pdfView.currentPage {
                    let index = doc.index(for: currentPage)
                    result(index)
                } else {
                    result(0)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    func view() -> UIView { pdfView }
}

// MARK: - Plugin Registration
class PdfViewerPlugin: NSObject, FlutterPlugin {
    static func register(with registrar: FlutterPluginRegistrar) {
        let factory = PdfViewerFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "native_pdf_viewer")
    }
}