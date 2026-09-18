import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class CallController {
  const CallController();

  Future<void> launchCall(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        debugPrint('[CallController] Could not launch tel: URI for $phoneNumber');
      }
    } catch (e) {
      debugPrint('[CallController] Error launching call: $e');
    }
  }
}
