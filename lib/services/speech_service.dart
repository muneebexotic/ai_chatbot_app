import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<bool> startListening({
    required Function(String) onResult,
    required Function(String) onError,
    required Function() onDone,
  }) async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done') {
          _isListening = false;
          onDone();
        }
      },
      onError: (error) {
        _isListening = false;
        onError(error.errorMsg);
      },
    );

    if (!available) return false;

    _isListening = true;

    _speech.listen(
      onResult: (val) => onResult(val.recognizedWords),
    );

    return true;
  }

  void stop() {
    _speech.stop();
    _isListening = false;
  }
}
