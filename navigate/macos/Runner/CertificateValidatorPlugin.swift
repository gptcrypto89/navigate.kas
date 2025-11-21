import FlutterMacOS
import Foundation
import Security

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
        var cleanRoot = trustedRootString
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let rootData = Data(base64Encoded: cleanRoot) else {
            print("Failed to decode base64 root certificate")
            // If it's not base64, maybe it's raw DER? Unlikely for a string input but possible if passed incorrectly.
            // For now assume PEM/Base64 string.
            return false
        }

        guard let rootCert = SecCertificateCreateWithData(nil, rootData as CFData) else {
            print("Failed to create root certificate from data")
            return false
        }

        // 3. Create Trust Object
        var trust: SecTrust?
        let policy = SecPolicyCreateSSL(true, domain as CFString)
        
        let status = SecTrustCreateWithCertificates(serverCert, policy, &trust)
        guard status == errSecSuccess, let trust = trust else {
            print("Failed to create trust object")
            return false
        }

        // 4. Set Anchor Certificates (The trusted root from blockchain)
        // We want to trust ONLY this root for this connection, or at least ensure the chain leads to it.
        // SecTrustSetAnchorCertificates sets the custom anchors.
        // SecTrustSetAnchorCertificatesOnly(trust, true) means ONLY trust these anchors, not system roots.
        // This effectively pins the certificate to this root.
        let anchors = [rootCert] as CFArray
        SecTrustSetAnchorCertificates(trust, anchors)
        SecTrustSetAnchorCertificatesOnly(trust, true)

        // 5. Evaluate Trust
        var error: CFError?
        let evalSuccess = SecTrustEvaluateWithError(trust, &error)
        
        if !evalSuccess {
            print("Trust evaluation failed: \(String(describing: error))")
            return false
        }

        return true
    }
}
