import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class CertificatePinningService {
  static const MethodChannel _channel = MethodChannel('com.navigate.kas/certificate_validator');

  /// Validates a server certificate against a trusted root certificate.
  /// 
  /// [serverCert] is the DER-encoded server certificate.
  /// [trustedRoot] is the PEM or DER encoded trusted root certificate from the blockchain.
  /// [domain] is the domain name to validate against.
  static Future<bool> validateCertificate({
    required Uint8List serverCert,
    required String trustedRoot,
    required String domain,
  }) async {
    try {
      final bool isValid = await _channel.invokeMethod('validateCertificate', {
        'serverCert': serverCert,
        'trustedRoot': trustedRoot,
        'domain': domain,
      });
      return isValid;
    } on PlatformException catch (e) {
      print('Certificate validation error: ${e.message}');
      return false;
    } catch (e) {
      print('Certificate validation error: $e');
      return false;
    }
  }
}
