import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a legal document in the system browser.
///
/// App Store Guideline 3.1.2 requires FUNCTIONAL Privacy Policy and Terms
/// links anywhere a subscription is sold — a dialog printing the URL as
/// selectable text (the previous behavior) is a known rejection pattern.
/// The dialog survives only as the failure fallback, so the URL is still
/// reachable on a device with no browser.
Future<void> openLegalUrl(BuildContext context, String title, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (opened || !context.mounted) return;
  showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: SelectableText(url),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
