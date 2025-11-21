import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:basic_utils/basic_utils.dart';

/// Dialog widget for displaying certificate information
class CertificateInfoDialog extends StatelessWidget {
  final Map<String, dynamic> certificateData;

  const CertificateInfoDialog({
    super.key,
    required this.certificateData,
  });

  static void show(BuildContext context, Map<String, dynamic> certificateData) {
    showDialog(
      context: context,
      builder: (context) => CertificateInfoDialog(certificateData: certificateData),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? certPem = certificateData['certificate'];
    String subject = 'Unknown';
    String issuer = 'Unknown';
    String validFrom = 'Unknown';
    String validTo = 'Unknown';
    String serialNumber = 'Unknown';
    String signatureAlgorithm = 'Unknown';
    bool parseError = false;

    if (certPem != null) {
      try {
        // Decode base64 directly (certificate is now passed as base64 without headers/footers)
        try {
          // Validate it's valid base64 by attempting to decode
          base64Decode(certPem!.replaceAll('\n', '').trim());
          // Format the base64 string with proper line breaks (64 chars per line) and add PEM headers
          final cleanBase64 = certPem!.replaceAll('\n', '').trim();
          final formattedBody = cleanBase64.replaceAllMapped(
            RegExp(r'.{64}'),
            (match) => '${match.group(0)}\n',
          ).trim();
          certPem = '-----BEGIN CERTIFICATE-----\n$formattedBody\n-----END CERTIFICATE-----';
        } catch (e) {
          // If decoding fails, try to use as-is with PEM headers
          print('Failed to decode base64 certificate: $e');
          if (certPem != null && !certPem!.contains('BEGIN CERTIFICATE')) {
            certPem = '-----BEGIN CERTIFICATE-----\n$certPem\n-----END CERTIFICATE-----';
          }
        }
        
        final x509 = X509Utils.x509CertificateFromPem(certPem!);
        // In basic_utils 5.7.0, subject and issuer are Maps or Strings, checking structure
        // Usually they are Map<String, dynamic> in this version
        final subjectMap = x509.subject;
        final issuerMap = x509.issuer;
        
        subject = subjectMap.toString();
        issuer = issuerMap.toString();
        
        // Try to extract CN if it's a map
        if (subjectMap is Map) {
          if (subjectMap.containsKey('2.5.4.3')) { // OID for Common Name
             subject = subjectMap['2.5.4.3'] ?? subject;
          } else if (subjectMap.containsKey('CN')) {
             subject = subjectMap['CN'] ?? subject;
          }
        }
        
        if (issuerMap is Map) {
          if (issuerMap.containsKey('2.5.4.3')) {
             issuer = issuerMap['2.5.4.3'] ?? issuer;
          } else if (issuerMap.containsKey('CN')) {
             issuer = issuerMap['CN'] ?? issuer;
          }
        }

        validFrom = x509.validity.notBefore.toString();
        validTo = x509.validity.notAfter.toString();
        serialNumber = x509.serialNumber?.toString() ?? 'Unknown';
        signatureAlgorithm = x509.signatureAlgorithm ?? 'Unknown';
        
        // Clean up if we still have raw string with CN=
        if (subject.contains('CN=')) {
           final match = RegExp(r'CN=([^,]+)').firstMatch(subject);
           if (match != null) subject = match.group(1) ?? subject;
        }
        if (issuer.contains('CN=')) {
           final match = RegExp(r'CN=([^,]+)').firstMatch(issuer);
           if (match != null) issuer = match.group(1) ?? issuer;
        }

      } catch (e) {
        print('Error parsing certificate: $e');
        parseError = true;
      }
    }

    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Row(
        children: [
          Icon(Icons.lock, color: Color(0xFF70C7BA)),
          SizedBox(width: 8),
          Text('Certificate Information', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (parseError)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(child: Text('Failed to parse certificate details', style: TextStyle(color: Colors.red))),
                  ],
                ),
              ),
              
            _buildInfoRow('Common Name (CN)', subject, Theme.of(context).colorScheme),
            const SizedBox(height: 12),
            _buildInfoRow('Issuer', issuer, Theme.of(context).colorScheme),
            const SizedBox(height: 12),
            _buildInfoRow('Valid From', validFrom, Theme.of(context).colorScheme),
            const SizedBox(height: 12),
            _buildInfoRow('Valid To', validTo, Theme.of(context).colorScheme),
            const SizedBox(height: 12),
            _buildInfoRow('Serial Number', serialNumber, Theme.of(context).colorScheme),
            const SizedBox(height: 12),
            _buildInfoRow('Signature Algorithm', signatureAlgorithm, Theme.of(context).colorScheme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        SelectableText(
          value,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface,
            fontFamily: value.length > 30 ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}

