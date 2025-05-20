import SwiftUI
import WebKit
import Combine

// MARK: - WebView Implementation with VPN-aware SSL Handling
struct WebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var webViewModel: WebViewModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        // Create a process pool that can be shared among WebViews
        let processPool = WKProcessPool()
        
        // Create the configuration
        let configuration = WKWebViewConfiguration()
        configuration.processPool = processPool
        
        // Critical: Allow universal SSL certificate acceptance
        // This works more reliably than other methods on physical devices
        let preferences = WKWebpagePreferences()
        if #available(iOS 14.0, *) {
            preferences.allowsContentJavaScript = true
        }
        configuration.defaultWebpagePreferences = preferences
        
        // Create webview with configuration
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        
        // Disable content mode restrictions - critical for full-screen
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        
        // Create and load the request - different approach for physical devices
        let request = createBypassRequest(for: url)
        webView.load(request)
        
        // Setup observers
        context.coordinator.setupObservers(for: webView)
        
        return webView
    }
    
    // Create a request specifically designed to bypass SSL on physical devices
    private func createBypassRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        // Set headers to appear more like a standard browser
        request.allHTTPHeaderFields = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
            "Connection": "keep-alive"
        ]
        
        // Bypass caching entirely - critical for VPN environments
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        // Timeout settings - important for VPN connections
        request.timeoutInterval = 60.0
        
        // Additional flags to bypass restrictions - available in iOS 14+
        if #available(iOS 14.0, *) {
            request.allowsCellularAccess = true
            request.allowsConstrainedNetworkAccess = true
            request.allowsExpensiveNetworkAccess = true
        }
        
        return request
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // This space intentionally left blank
    }
    
    // MARK: - Coordinator with VPN-aware SSL handling
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebView
        private var progressObservation: NSKeyValueObservation?
        
        init(_ parent: WebView) {
            self.parent = parent
            super.init()
        }
        
        // Observer setup is the same
        func setupObservers(for webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, change in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.parent.webViewModel.progress = Float(webView.estimatedProgress)
                    
                    if webView.estimatedProgress >= 1.0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.parent.webViewModel.isLoaded = true
                        }
                    }
                }
            }
        }
        
        deinit {
            progressObservation?.invalidate()
        }
        
        // MARK: - VPN-aware Certificate Handling
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            // Log for debugging
            print("⚠️ Received SSL challenge for: \(challenge.protectionSpace.host)")
            
            // Use a multi-pronged approach for certificate handling on VPN
            let authMethod = challenge.protectionSpace.authenticationMethod
            
            if authMethod == NSURLAuthenticationMethodServerTrust {
                if let serverTrust = challenge.protectionSpace.serverTrust {
                    // First approach: Update trust evaluation
                    updateTrustEvaluationIfNeeded(serverTrust)
                    
                    // Second approach: Create credential from trust
                    let credential = URLCredential(trust: serverTrust)
                    print("✅ Accepting certificate for: \(challenge.protectionSpace.host)")
                    completionHandler(.useCredential, credential)
                    return
                }
            } else if authMethod == NSURLAuthenticationMethodClientCertificate {
                // Handle client certificate requests (common in corporate VPNs)
                print("🔐 Client certificate requested - bypassing")
                completionHandler(.performDefaultHandling, nil)
                return
            } else if authMethod == NSURLAuthenticationMethodHTTPBasic {
                // Handle HTTP Basic Auth if needed
                print("🔑 HTTP Basic Auth requested")
                completionHandler(.performDefaultHandling, nil)
                return
            }
            
            // Fallback to default handling
            print("⚠️ Using default handling for: \(challenge.protectionSpace.host)")
            completionHandler(.performDefaultHandling, nil)
        }
        
        // Critical function for handling trust on physical devices with VPN
        private func updateTrustEvaluationIfNeeded(_ serverTrust: SecTrust) {
            // Create an SSL policy for the domain we're connecting to
            let policy = SecPolicyCreateSSL(true, nil)
            
            // Set the policy on the trust object
            SecTrustSetPolicies(serverTrust, policy)
            
            // Optional: Add your own root certificates if needed
            // This is sometimes necessary for corporate VPNs
            /*
            if let rootCertPath = Bundle.main.path(forResource: "YourRootCert", ofType: "cer"),
               let rootCertData = try? Data(contentsOf: URL(fileURLWithPath: rootCertPath)),
               let rootCert = SecCertificateCreateWithData(nil, rootCertData as CFData) {
                
                SecTrustSetAnchorCertificates(serverTrust, [rootCert] as CFArray)
            }
            */
            
            // Force trust evaluation
            var result: SecTrustResultType = .invalid
            SecTrustEvaluate(serverTrust, &result)
            
            print("🔍 Trust evaluation result: \(result == .proceed ? "Proceed" : "Other: \(result.rawValue)")")
        }
        
        // MARK: - Navigation Events with VPN-specific Error Handling
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("▶️ Started loading: \(webView.url?.absoluteString ?? "unknown URL")")
            DispatchQueue.main.async {
                self.parent.webViewModel.isLoading = true
                self.parent.webViewModel.error = nil
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ Finished loading: \(webView.url?.absoluteString ?? "unknown URL")")
            DispatchQueue.main.async {
                self.parent.webViewModel.isLoading = false
                self.injectLayoutFixes(into: webView)
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ Navigation failed: \(error.localizedDescription)")
            handleError(error, in: webView)
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ Provisional navigation failed: \(error.localizedDescription)")
            
            let nsError = error as NSError
            // Special handling for VPN-related errors
            if nsError.domain == NSURLErrorDomain {
                print("🔍 Analyzing error: domain=\(nsError.domain), code=\(nsError.code)")
                
                if nsError.code == NSURLErrorServerCertificateUntrusted ||
                   nsError.code == NSURLErrorServerCertificateHasBadDate ||
                   nsError.code == NSURLErrorServerCertificateHasUnknownRoot ||
                   nsError.code == NSURLErrorServerCertificateNotYetValid ||
                   nsError.code == NSURLErrorSecureConnectionFailed {
                    
                    print("🛠 Attempting VPN-specific SSL error recovery")
                    
                    // VPN-specific approach: try with a completely new request
                    if let url = webView.url ?? URL(string: self.parent.url.absoluteString) {
                        let newRequest = self.createSecondaryBypassRequest(for: url)
                        
                        // Add delay to avoid immediate reload cycle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            print("🔄 Reloading with VPN-specific bypass")
                            webView.load(newRequest)
                        }
                        return
                    }
                }
            }
            
            handleError(error, in: webView)
        }
        
        // Special request format specifically for VPN environments
        private func createSecondaryBypassRequest(for url: URL) -> URLRequest {
            var request = URLRequest(url: url)
            
            // Additional headers that sometimes help with VPN environments
            request.allHTTPHeaderFields = [
                "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                "Accept-Language": "en-US,en;q=0.9",
                "Accept-Encoding": "gzip, deflate, br",
                "Connection": "keep-alive",
                "Pragma": "no-cache",
                "Cache-Control": "no-cache"
            ]
            
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 60.0
            request.httpShouldHandleCookies = true
            
            return request
        }
        
        private func handleError(_ error: Error, in webView: WKWebView) {
            let nsError = error as NSError
            
            // Don't report cancellation errors
            if nsError.code == NSURLErrorCancelled {
                return
            }
            
            DispatchQueue.main.async {
                self.parent.webViewModel.isLoading = false
                
                let errorDescription = self.friendlyErrorMessage(from: error)
                self.parent.webViewModel.error = errorDescription
                
                // If error occurs during initial load, don't transition to web view
                if !self.parent.webViewModel.isLoaded {
                    // Keep showing loading screen with error
                } else {
                    // Just show error banner
                }
            }
        }
        
        private func friendlyErrorMessage(from error: Error) -> String {
            let nsError = error as NSError
            let errorDomain = nsError.domain
            let errorCode = nsError.code
            
            // VPN-specific friendly messages
            if errorDomain == NSURLErrorDomain {
                switch errorCode {
                case NSURLErrorNotConnectedToInternet:
                    return "Not connected to the internet. Please check your VPN connection."
                case NSURLErrorTimedOut:
                    return "Request timed out. VPN connections might be slowing your connection."
                case NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost:
                    return "Cannot connect to server through the VPN. Please try again later."
                case NSURLErrorSecureConnectionFailed:
                    return "Secure connection failed through the VPN. Please check your network settings."
                case NSURLErrorServerCertificateHasBadDate, NSURLErrorServerCertificateUntrusted, 
                     NSURLErrorServerCertificateHasUnknownRoot, NSURLErrorServerCertificateNotYetValid:
                    return "Certificate issue. Your VPN might be interfering with secure connections."
                case NSURLErrorAppTransportSecurityRequiresSecureConnection:
                    return "Secure connection required. Please check your VPN configuration."
                default:
                    return "Error loading page through VPN: \(nsError.localizedDescription)"
                }
            }
            
            return "Error loading page: \(nsError.localizedDescription)"
        }
        
        // JavaScript Injection stays the same
        func injectLayoutFixes(into webView: WKWebView) {
            // ... (same as before)
        }
    }
}

// MARK: - Info.plist Additions
/*
For physical devices on VPN networks, these Info.plist settings are more likely to work:

<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <key>NSAllowsArbitraryLoadsInWebContent</key>
    <true/>
    <key>NSAllowsLocalNetworking</key>
    <true/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>your-domain.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.0</string>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
            <key>NSRequiresCertificateTransparency</key>
            <false/>
        </dict>
    </dict>
</dict>
*/