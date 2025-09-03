// Image Generation Constants
class ImageGenerationConstants {
  // UI Constants
  static const double dialogMaxWidth = 500.0;
  static const double dialogMaxHeight = 600.0;
  static const double previewImageHeight = 250.0;
  static const double previewImageWidth = 300.0;
  static const double thumbnailSize = 80.0;
  
  // Animation durations
  static const Duration fadeInDuration = Duration(milliseconds: 300);
  static const Duration slideUpDuration = Duration(milliseconds: 400);
  static const Duration loadingAnimationDuration = Duration(milliseconds: 1500);
  static const Duration pulseAnimationDuration = Duration(milliseconds: 800);
  
  // API Constants
  static const int maxRetries = 3;
  static const Duration requestTimeout = Duration(seconds: 60);
  static const Duration retryDelay = Duration(seconds: 2);
  
  // Validation Constants
  static const int minPromptLength = 3;
  static const int maxPromptLength = 1000;
  static const int maxNegativePromptLength = 500;
  static const int maxSeedValue = 2147483647; // Max int32
  static const double minGuidanceScale = 1.0;
  static const double maxGuidanceScale = 20.0;
  static const int minSteps = 10;
  static const int maxSteps = 150;
  
  // File and Storage Constants
  static const int maxImageSizeBytes = 10 * 1024 * 1024; // 10MB
  static const int maxCacheAgeHours = 24;
  static const String imageFileExtension = '.png';
  static const String cacheDirectoryName = 'generated_images';
  
  // Usage Limits (Free Tier)
  static const int freeImagesPerDay = 5;
  static const int freeImagesPerHour = 2;
  static const int premiumImagesPerDay = 100;
  static const int premiumImagesPerHour = 20;
}

// Default Prompts and Suggestions
class ImagePromptData {
  static const List<Map<String, dynamic>> categories = [
    {
      'title': 'Nature & Landscapes',
      'icon': '🌄',
      'prompts': [
        'A serene mountain lake at sunset with golden reflections',
        'Mystical forest path covered in morning mist',
        'Cherry blossoms falling in a Japanese garden',
        'Northern lights dancing over a snowy landscape',
        'Tropical beach with crystal clear turquoise water',
        'Ancient redwood forest with sunbeams filtering through',
      ],
    },
    {
      'title': 'Fantasy & Sci-Fi',
      'icon': '🔮',
      'prompts': [
        'Floating islands connected by rainbow bridges',
        'Cyberpunk city with neon lights and flying cars',
        'Dragon soaring over a medieval castle',
        'Space station orbiting a distant planet',
        'Magical library with floating books and glowing orbs',
        'Steampunk airship sailing through cloudy skies',
      ],
    },
    {
      'title': 'Animals & Creatures',
      'icon': '🦁',
      'prompts': [
        'Majestic lion with a flowing golden mane',
        'Colorful parrot perched on a tropical branch',
        'Playful dolphins jumping in ocean waves',
        'Wise old owl sitting on a moonlit branch',
        'Graceful swan gliding across a peaceful pond',
        'Curious fox exploring a winter wonderland',
      ],
    },
    {
      'title': 'Art & Abstract',
      'icon': '🎨',
      'prompts': [
        'Vibrant geometric patterns in rainbow colors',
        'Watercolor splash with flowing organic shapes',
        'Mandala design with intricate sacred geometry',
        'Abstract explosion of paint and light',
        'Minimalist zen garden with flowing sand patterns',
        'Kaleidoscope of butterflies in motion',
      ],
    },
    {
      'title': 'Architecture & Cities',
      'icon': '🏛️',
      'prompts': [
        'Gothic cathedral with stunning stained glass windows',
        'Modern skyscraper reflecting the sunset sky',
        'Ancient ruins covered in lush green vines',
        'Cozy cottage with a thatched roof and flower garden',
        'Futuristic city with glass towers and sky bridges',
        'Traditional Japanese temple in autumn colors',
      ],
    },
    {
      'title': 'Food & Objects',
      'icon': '🍎',
      'prompts': [
        'Delicious chocolate cake with fresh berries',
        'Vintage camera on a wooden table with soft lighting',
        'Fresh fruit arrangement with morning dew drops',
        'Steaming cup of coffee with latte art',
        'Antique pocket watch on an old map',
        'Bouquet of sunflowers in a rustic vase',
      ],
    },
  ];
  
  static const List<String> quickPrompts = [
    'Beautiful sunset over mountains',
    'Cute cat sleeping peacefully',
    'Colorful hot air balloons in sky',
    'Cozy fireplace in winter cabin',
    'Majestic eagle soaring high',
    'Enchanted fairy tale castle',
    'Peaceful zen garden',
    'Vibrant coral reef underwater',
    'Ancient tree with glowing lights',
    'Starry night sky over lake',
  ];
  
  static const List<String> styleModifiers = [
    'photorealistic',
    'oil painting style',
    'watercolor artwork',
    'digital art',
    'pencil sketch',
    'cartoon illustration',
    'anime style',
    'vintage photograph',
    'abstract art',
    'impressionist painting',
    'surreal art',
    'minimalist design',
  ];
  
  static const List<String> qualityModifiers = [
    'highly detailed',
    'ultra high resolution',
    '8K quality',
    'professional photography',
    'studio lighting',
    'perfect composition',
    'award winning',
    'masterpiece',
    'trending on artstation',
    'cinematic lighting',
  ];
  
  static const List<String> negativePrompts = [
    'blurry, low quality, pixelated',
    'distorted, deformed, ugly',
    'text, watermark, signature',
    'dark, gloomy, depressing',
    'violent, disturbing, inappropriate',
    'duplicate, repetitive, boring',
    'oversaturated, artificial, fake',
    'grainy, noisy, artifacts',
  ];
}

// Error Messages
class ImageGenerationErrors {
  static const String networkError = 'Network connection failed. Please check your internet connection and try again.';
  static const String apiError = 'Image generation service is temporarily unavailable. Please try again later.';
  static const String invalidPrompt = 'Please enter a valid prompt between 3-1000 characters.';
  static const String promptTooShort = 'Prompt is too short. Please add more details (minimum 3 characters).';
  static const String promptTooLong = 'Prompt is too long. Please shorten it to under 1000 characters.';
  static const String inappropriateContent = 'This prompt may contain inappropriate content. Please try a different prompt.';
  static const String usageLimitExceeded = 'You have reached your daily image generation limit. Upgrade to Premium for unlimited access.';
  static const String storageError = 'Failed to save the generated image. Please try again.';
  static const String downloadError = 'Failed to download the image. Please check your internet connection.';
  static const String cacheError = 'Failed to cache the image locally.';
  static const String unknownError = 'An unexpected error occurred. Please try again.';
  
  static String getRetryMessage(int attemptNumber) {
    return 'Generation failed (attempt $attemptNumber). Retrying...';
  }
  
  static String getTimeoutMessage(int seconds) {
    return 'Generation is taking longer than expected ($seconds seconds). Please wait...';
  }
}

// Success Messages
class ImageGenerationMessages {
  static const String generationStarted = 'Generating your image... This may take a few moments.';
  static const String generationCompleted = 'Image generated successfully!';
  static const String imageSaved = 'Image saved to your gallery.';
  static const String imageCopied = 'Image copied to clipboard.';
  static const String imageShared = 'Image shared successfully.';
  static const String promptEnhanced = 'Prompt enhanced for better results.';
  static const String settingsUpdated = 'Image generation settings updated.';
  
  // Add the missing status getters
  static const String readyStatus = 'Ready to generate';
  static const String errorStatus = 'Generation failed';
  static const String successStatus = 'Generation completed';
  static const String loadingStatus = 'Generating...';
  
  static String getGenerationProgress(int percentage) {
    if (percentage < 25) return 'Initializing generation...';
    if (percentage < 50) return 'Creating base structure...';
    if (percentage < 75) return 'Adding details and refinements...';
    if (percentage < 90) return 'Applying final touches...';
    return 'Almost done...';
  }
}

// UI Text Constants
class ImageGenerationUI {
  // Dialog Titles
  static const String generateImageTitle = 'Generate Image';
  static const String imagePreviewTitle = 'Generated Image';
  static const String imageSettingsTitle = 'Generation Settings';
  static const String promptSuggestionsTitle = 'Prompt Suggestions';
  
  // Button Labels
  static const String generateButton = 'Generate Image';
  static const String regenerateButton = 'Regenerate';
  static const String saveButton = 'Save Image';
  static const String shareButton = 'Share';
  static const String copyButton = 'Copy';
  static const String downloadButton = 'Download';
  static const String enhancePromptButton = 'Enhance Prompt';
  static const String clearButton = 'Clear';
  static const String cancelButton = 'Cancel';
  static const String retryButton = 'Retry';
  static const String upgradeButton = 'Upgrade to Premium';
  
  // Input Labels
  static const String promptLabel = 'Describe your image';
  static const String promptHint = 'E.g., "A majestic mountain landscape at sunset with snow-capped peaks"';
  static const String negativePromptLabel = 'Negative prompt (optional)';
  static const String negativePromptHint = 'What you don\'t want in the image';
  static const String seedLabel = 'Seed (optional)';
  static const String seedHint = 'Random number for reproducible results';
  
  // Settings Labels
  static const String sizeLabel = 'Image Size';
  static const String qualityLabel = 'Quality';
  static const String styleLabel = 'Style';
  static const String stepsLabel = 'Generation Steps';
  static const String guidanceLabel = 'Guidance Scale';
  
  // Status Messages
  static const String loadingStatus = 'Generating...';
  static const String readyStatus = 'Ready to generate';
  static const String errorStatus = 'Generation failed';
  static const String successStatus = 'Generation completed';
  
  // Helper Text
  static const String promptHelperText = 'Be specific and descriptive for best results';
  static const String qualityHelperText = 'Higher quality takes longer but produces better results';
  static const String sizeHelperText = 'Larger images use more credits';
  static const String stepsHelperText = 'More steps = higher quality but slower generation';
  static const String seedHelperText = 'Same seed with same prompt produces identical results';
  
  // Usage Info
  static const String freeUsageInfo = 'Free users: 5 images per day';
  static const String premiumUsageInfo = 'Premium users: Unlimited images';
  static const String costInfo = 'This generation will cost 1 credit';
  
  static String getRemainingUsage(int remaining, int total) {
    return 'Remaining today: $remaining / $total';
  }
  
  static String getImageDimensions(int width, int height) {
    return '${width}×$height pixels';
  }
}