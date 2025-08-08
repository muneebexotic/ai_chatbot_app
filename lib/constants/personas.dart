class Personas {
  // Based on your original personas with premium restrictions
  static const Map<String, Map<String, dynamic>> all = {
    'Default': {
      'name': 'Default',
      'description': 'A helpful AI assistant ready to help with any questions',
      'icon': '🤖',
      'systemPrompt': '', // Your original empty prompt
      'isPremium': false,
    },
    'Friendly Assistant': {
      'name': 'Friendly Assistant',
      'description': 'A friendly and helpful assistant that answers casually and politely',
      'icon': '😊',
      'systemPrompt': 'You are a friendly and helpful assistant. Answer casually and politely.',
      'isPremium': false,
    },
    'Strict Teacher': {
      'name': 'Strict Teacher',
      'description': 'A firm, to-the-point teacher with no jokes',
      'icon': '👨‍🏫',
      'systemPrompt': 'You are a strict teacher. Be firm, to the point, and no jokes.',
      'isPremium': false,
    },
    'Wise Philosopher': {
      'name': 'Wise Philosopher',
      'description': 'A wise philosopher who speaks in deep, thought-provoking language',
      'icon': '🤔',
      'systemPrompt': 'You are a wise philosopher. Speak in deep, thought-provoking language.',
      'isPremium': true,
    },
    'Sarcastic Developer': {
      'name': 'Sarcastic Developer',
      'description': 'A sarcastic software engineer with dry humor and technical sarcasm',
      'icon': '👨‍💻',
      'systemPrompt': 'You are a sarcastic software engineer. Use dry humor and technical sarcasm.',
      'isPremium': true,
    },
    'Motivational Coach': {
      'name': 'Motivational Coach',
      'description': 'A high-energy motivational coach with encouragement',
      'icon': '💪',
      'systemPrompt': 'You are a motivational coach. Respond with high energy and encouragement.',
      'isPremium': true,
    },
  };

  // Get personas available for subscription status
  static Map<String, Map<String, dynamic>> getAvailablePersonas(bool isPremium) {
    if (isPremium) {
      return all;
    }
    
    // Free users only get non-premium personas
    return Map.fromEntries(
      all.entries.where((entry) => entry.value['isPremium'] == false),
    );
  }

  // Get persona by ID
  static Map<String, dynamic>? getPersona(String id) {
    return all[id];
  }

  // Check if persona is premium
  static bool isPersonaPremium(String id) {
    return all[id]?['isPremium'] ?? false;
  }

  // Get system prompt for persona
  static String getSystemPrompt(String id) {
    return all[id]?['systemPrompt'] ?? all['none']!['systemPrompt'];
  }

  // Get display name for persona
  static String getDisplayName(String id) {
    return all[id]?['name'] ?? 'Default Assistant';
  }

  // Get free persona IDs
  static List<String> get freePersonaIds {
    return all.entries
        .where((entry) => entry.value['isPremium'] == false)
        .map((entry) => entry.key)
        .toList();
  }

  // Get premium persona IDs
  static List<String> get premiumPersonaIds {
    return all.entries
        .where((entry) => entry.value['isPremium'] == true)
        .map((entry) => entry.key)
        .toList();
  }

  // Get count of available personas
  static int getAvailablePersonaCount(bool isPremium) {
    return getAvailablePersonas(isPremium).length;
  }

  // Validate persona access
  static bool canAccessPersona(String id, bool isPremium) {
    final persona = all[id];
    if (persona == null) return false;
    
    if (persona['isPremium'] == true && !isPremium) {
      return false;
    }
    
    return true;
  }
}