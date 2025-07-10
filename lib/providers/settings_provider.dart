import 'package:flutter/material.dart';

class SettingsProvider with ChangeNotifier {
  // Default is 'none' for no persona
  String _persona = 'none';

  String get persona => _persona;

  void setPersona(String newPersona) {
    _persona = newPersona;
    notifyListeners();
  }
}
