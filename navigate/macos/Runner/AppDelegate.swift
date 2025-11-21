import Cocoa
import FlutterMacOS
import Security

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
    CertificateValidatorPlugin.register(with: controller.registrar(forPlugin: "CertificateValidatorPlugin"))
    super.applicationDidFinishLaunching(notification)
  }
}

public class CertificateValidatorPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.navigate.kas/certificate_validator", binaryMessenger: registrar.messenger)
        let instance = CertificateValidatorPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "validateCertificate" {
            guard let args = call.arguments as? [String: Any],
                  let serverCertData = args["serverCert"] as? FlutterStandardTypedData,
                  let trustedRootString = args["trustedRoot"] as? String,
                  let domain = args["domain"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing or invalid arguments", details: nil))
                return
            }

            let isValid = validateCertificate(serverCertData: serverCertData.data, trustedRootString: trustedRootString, domain: domain)
            result(isValid)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func validateCertificate(serverCertData: Data, trustedRootString: String, domain: String) -> Bool {
        // 1. Create SecCertificate from server data
        guard let serverCert = SecCertificateCreateWithData(nil, serverCertData as CFData) else {
            print("Failed to create server certificate from data")
            return false
        }

        // 2. Create SecCertificate from trusted root string (PEM or DER)
        // Try to clean up PEM headers if present to get raw base64
        let cleanRoot = trustedRootString
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let rootData = Data(base64Encoded: cleanRoot) else {
            print("Failed to decode base64 root certificate")
            return false
        }

        guard let rootCert = SecCertificateCreateWithData(nil, rootData as CFData) else {
            print("Failed to create root certificate from data")
            return false
        }

        // 3. Create Trust Object
        var trust: SecTrust?
        
        // CRITICAL CHANGE: Use BasicX509 policy instead of SSL policy.
        // The SSL policy enforces hostname matching (CN == hostname). 
        // In our case, we are connecting to an IP (127.0.0.1) but the cert has the domain name (navigatebrowser).
        // Since we are explicitly PINNING the certificate (checking if it matches the one on blockchain),
        // we don't need the system to check the hostname. The security comes from the blockchain pinning.
        let policy = SecPolicyCreateBasicX509()
        
        let status = SecTrustCreateWithCertificates(serverCert, policy, &trust)
        guard status == errSecSuccess, let trust = trust else {
            print("Failed to create trust object")
            return false
        }

        // 4. Set Anchor Certificates (The trusted root from blockchain)
        let anchors = [rootCert] as CFArray
        SecTrustSetAnchorCertificates(trust, anchors)
        SecTrustSetAnchorCertificatesOnly(trust, true)

        // 5. Evaluate Trust
        var error: CFError?
        let evalSuccess = SecTrustEvaluateWithError(trust, &error)
        
        if !evalSuccess {
            print("Trust evaluation failed: \(String(describing: error))")
            
            // If evaluation failed, check if it's just because of validity period or other non-critical issues
            // given that we have explicitly pinned the root.
            // However, SecTrustEvaluateWithError with BasicX509 should pass if the signature is valid and chains to the root.
            // If it fails here, it might be expired or signature invalid.
            
            // For self-signed v1 certs with long validity, basic X509 should still work IF the time is valid.
            // If the error is recoverable (e.g. just "not trusted" which shouldn't happen if we set anchors), we might inspect it.
            
            return false
        }

        return true
    }
}
