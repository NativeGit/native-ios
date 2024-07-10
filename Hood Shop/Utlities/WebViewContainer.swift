import SwiftUI
import WebKit

// Observable class to manage WKWebView and its dynamic height
class WebViewContainer: ObservableObject {
    @Published var webView: WKWebView = WKWebView()
    @Published var dynamicHeight: CGFloat = .zero

    init() {
        // Optionally set navigation delegate or other configurations here
    }
}

// SwiftUI View to wrap WKWebView
struct WebView: UIViewRepresentable {
    @ObservedObject var container: WebViewContainer
    var url: URL

    // Create the WKWebView and load the initial request
    func makeUIView(context: Context) -> WKWebView {
        let webView = container.webView
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }

    // Update the UIView (not used here)
    func updateUIView(_ uiView: WKWebView, context: Context) {}

    // Create the Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Coordinator to handle WKWebView navigation delegate methods
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        // Adjust the dynamic height of the web view when the content is fully loaded
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.readyState") { (complete, error) in
                if complete != nil {
                    webView.evaluateJavaScript("document.body.scrollHeight") { (height, error) in
                        DispatchQueue.main.async {
                            if let height = height as? CGFloat {
                                self.parent.container.dynamicHeight = height
                            }
                        }
                    }
                }
            }
        }
    }
}
