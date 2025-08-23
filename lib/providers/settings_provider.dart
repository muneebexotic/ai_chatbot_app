import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {

  String _persona = 'Default';

  static const List<Map<String, dynamic>> availablePersonas = [
    {'id': 'Default', 'name': 'Default', 'isPremium': false},
    {'id': 'Friendly Assistant', 'name': 'Friendly Assistant', 'isPremium': false},
    {'id': 'Strict Teacher', 'name': 'Strict Teacher', 'isPremium': false},
    {'id': 'Wise Philosopher', 'name': 'Wise Philosopher', 'isPremium': true},
    {'id': 'Sarcastic Developer', 'name': 'Sarcastic Developer', 'isPremium': true},
    {'id': 'Motivational Coach', 'name': 'Motivational Coach', 'isPremium': true},
  ];

  String get persona => _persona;

  // Get available personas based on subscription status
  List<Map<String, dynamic>> getAvailablePersonas(bool isPremium) {
    if (isPremium) {
      return availablePersonas;
    } else {
      // Free users get first 3 personas only
      return availablePersonas.where((persona) => !persona['isPremium']).toList();
    }
  }

  // Get persona display name
  String get personaDisplayName {
    final persona = availablePersonas.firstWhere(
      (p) => p['id'] == _persona,
      orElse: () => availablePersonas.first,
    );
    return persona['name'];
  }

  // Check if current persona is premium
  bool get isCurrentPersonaPremium {
    final persona = availablePersonas.firstWhere(
      (p) => p['id'] == _persona,
      orElse: () => availablePersonas.first,
    );
    return persona['isPremium'] ?? false;
  }

  // Initialize settings from SharedPreferences
  Future<void> initializeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _persona = prefs.getString('selected_persona') ?? 'Default';
      
      print('✅ Settings loaded: Persona = $_persona');
      notifyListeners();
    } catch (e) {
      print('❌ Error loading settings: $e');
    }
  }

  // Set persona with validation
  Future<void> setPersona(String newPersona, {bool isPremium = false}) async {
    try {
      // Find the persona details
      final personaDetails = availablePersonas.firstWhere(
        (p) => p['id'] == newPersona,
        orElse: () => availablePersonas.first,
      );

      // Check if user can access this persona
      if (personaDetails['isPremium'] == true && !isPremium) {
        print('⚠️ Attempted to select premium persona without subscription: $newPersona');
        throw Exception('This persona requires Premium subscription');
      }

      _persona = newPersona;
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_persona', newPersona);
      
      print('✅ Persona updated: $_persona (${personaDetails['name']})');
      notifyListeners();
    } catch (e) {
      print('❌ Error setting persona: $e');
      rethrow;
    }
  }

  // Reset to default persona when subscription expires
  Future<void> resetToFreePersona() async {
    if (isCurrentPersonaPremium) {
      print('🔄 Resetting to free persona due to subscription expiry');
      await setPersona('Default', isPremium: false);
    }
  }

  // Get persona description for UI
  String getPersonaDescription(String personaId) {
    switch (personaId) {
      case 'Default':
        return 'A helpful AI assistant ready to help with any questions';
      case 'Friendly Assistant':
        return 'A friendly and helpful assistant that answers casually and politely';
      case 'Strict Teacher':
        return 'A firm, to-the-point teacher with no jokes';
      case 'Wise Philosopher':
        return 'A wise philosopher who speaks in deep, thought-provoking language';
      case 'Sarcastic Developer':
        return 'A sarcastic software engineer with dry humor and technical sarcasm';
      case 'Motivational Coach':
        return 'A high-energy motivational coach with encouragement';
      default:
        return 'AI Assistant';
    }
  }

  // Get persona system prompt for AI (matching your original prompts)
  String getPersonaSystemPrompt(String personaId) {
    switch (personaId) {
      case 'Friendly Assistant':
        return 'You are a friendly and helpful assistant. Answer casually and politely.';
      case 'Strict Teacher':
        return 'You are a strict teacher. Be firm, to the point, and no jokes.';
      case 'Wise Philosopher':
        return 'You are a wise philosopher. Speak in deep, thought-provoking language.';
      case 'Sarcastic Developer':
        return 'You are a sarcastic software engineer. Use dry humor and technical sarcasm.';
      case 'Motivational Coach':
        return 'You are a motivational coach. Respond with high energy and encouragement.';
      case 'Default':
      default:
        return ''; // Your original empty prompt for default
    }
  }

  // Check if a specific persona is available for current user
  bool isPersonaAvailable(String personaId, bool isPremium) {
    final persona = availablePersonas.firstWhere(
      (p) => p['id'] == personaId,
      orElse: () => {'isPremium': true},
    );
    
    if (persona['isPremium'] == true && !isPremium) {
      return false;
    }
    return true;
  }

  // Get count of available personas
  int getAvailablePersonaCount(bool isPremium) {
    return getAvailablePersonas(isPremium).length;
  }

  // Get premium persona count
  int get premiumPersonaCount {
    return availablePersonas.where((p) => p['isPremium'] == true).length;
  }

  // Validate current persona access
  Future<bool> validateCurrentPersonaAccess(bool isPremium) async {
    if (isCurrentPersonaPremium && !isPremium) {
      // Current persona requires premium but user is not premium
      await resetToFreePersona();
      return false;
    }
    return true;
  }
}