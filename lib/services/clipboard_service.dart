import 'package:fluttertoast/fluttertoast.dart';
import 'package:clipboard/clipboard.dart';

class ClipboardService {
  static void copyText(String text) {
    FlutterClipboard.copy(text).then((_) {
      Fluttertoast.showToast(msg: 'Copied to clipboard');
    });
  }
}
