import 'package:flutter/services.dart';

import 'package:ai_chatbot_app/core/ui/app_messenger.dart';

/// Copies text to the system clipboard.
///
/// PRD §2.2 cuts both `clipboard` and `fluttertoast`: the first duplicates
/// `Clipboard` from `flutter/services`, and the second draws a platform toast
/// that ignores the design system.
abstract final class ClipboardService {
  const ClipboardService._();

  /// Copies [text] and confirms it.
  ///
  /// Android 13+ shows its own copy confirmation, so suppress ours there to
  /// avoid telling the user the same thing twice — pass `announce: false` from
  /// call sites that already give visible feedback.
  static Future<void> copyText(String text, {bool announce = true}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (announce) {
      AppMessenger.show('Copied', tone: AppMessageTone.success);
    }
  }
}
