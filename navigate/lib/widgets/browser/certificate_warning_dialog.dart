import 'package:flutter/material.dart';

/// A dialog that warns users about unsecured connections (no SSL certificate)
/// and allows them to choose whether to proceed or go back.
class CertificateWarningDialog {
  /// Shows a warning dialog for unsecured connections.
  /// 
  /// Returns true if the user chooses to proceed, false if they choose to go back,
  /// or null if the dialog is dismissed.
  static Future<bool?> show(BuildContext context, String domain) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Unsecured Connection', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'No valid SSL certificate found for $domain.\n\nYour connection to this site is not secure. Do you want to proceed?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go Back', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Proceed Anyway', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
