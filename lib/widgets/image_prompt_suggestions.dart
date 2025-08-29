import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/themes_provider.dart';
import '../utils/app_theme.dart';
import '../components/ui/app_text.dart';
import '../models/image_generation_request.dart';

class ImagePromptSuggestions extends StatefulWidget {
  const ImagePromptSuggestions({super.key});

  @override
  State<ImagePromptSuggestions> createState() => _ImagePromptSuggestionsState();
}

class _ImagePromptSuggestionsState extends State<ImagePromptSuggestions>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Categories of prompt suggestions
  final Map<String, List<Map<String, String>>> _promptCategories = {
    'Popular': [
      {
        'prompt': 'A majestic mountain landscape at golden hour with misty valleys',
        'description': 'Nature & Landscapes',
        'tags': 'mountains, sunset, mist, landscape, golden hour'
      },
      {
        'prompt': 'A cyberpunk cityscape with neon lights and flying cars at night',
        'description': 'Sci-Fi & Fantasy',
        'tags': 'cyberpunk, neon, futuristic, city, night'
      },
      {
        'prompt': 'A cozy coffee shop interior with warm lighting and plants',
        'description': 'Interior Design',
        'tags': 'coffee, cozy, interior, plants, warm'
      },
      {
        'prompt': 'A magical forest with glowing mushrooms and fairy lights',
        'description': 'Fantasy & Magic',
        'tags': 'forest, magic, mushrooms, fairy, fantasy'
      },
      {
        'prompt': 'Abstract geometric patterns in vibrant colors',
        'description': 'Abstract Art',
        'tags': 'abstract, geometric, colorful, patterns'
      },
      {
        'prompt': 'A vintage car on a coastal road during sunset',
        'description': 'Automotive & Travel',
        'tags': 'vintage, car, coast, sunset, travel'
      },
    ],
    'Nature': [
      {
        'prompt': 'A serene lake surrounded by autumn trees with colorful leaves',
        'description': 'Autumn Scenery',
        'tags': 'lake, autumn, trees, colorful, peaceful'
      },
      {
        'prompt': 'Tropical beach with crystal clear water and palm trees',
        'description': 'Tropical Paradise',
        'tags': 'beach, tropical, clear water, palm trees'
      },
      {
        'prompt': 'Snow-covered pine forest in the early morning mist',
        'description': 'Winter Wonderland',
        'tags': 'snow, pine forest, winter, mist, morning'
      },
      {
        'prompt': 'A field of sunflowers under a blue sky with white clouds',
        'description': 'Summer Fields',
        'tags': 'sunflowers, field, blue sky, clouds, summer'
      },
      {
        'prompt': 'Rocky desert landscape with cacti and dramatic lighting',
        'description': 'Desert Beauty',
        'tags': 'desert, rocks, cacti, dramatic, landscape'
      },
      {
        'prompt': 'Waterfall cascading down moss-covered rocks in a lush forest',
        'description': 'Forest Waterfall',
        'tags': 'waterfall, moss, rocks, forest, lush'
      },
    ],
    'Portraits': [
      {
        'prompt': 'Professional headshot of a confident businesswoman in modern office',
        'description': 'Business Portrait',
        'tags': 'business, professional, confident, office'
      },
      {
        'prompt': 'Elderly man with wise eyes and weathered hands holding a book',
        'description': 'Character Study',
        'tags': 'elderly, wise, weathered, book, character'
      },
      {
        'prompt': 'Young artist with paint-stained apron in a bright studio',
        'description': 'Artist Portrait',
        'tags': 'artist, young, paint, studio, creative'
      },
      {
        'prompt': 'Child laughing while playing in a garden full of flowers',
        'description': 'Joyful Moment',
        'tags': 'child, laughing, garden, flowers, joy'
      },
      {
        'prompt': 'Fashion model in elegant evening dress with dramatic lighting',
        'description': 'Fashion Photography',
        'tags': 'fashion, model, elegant, dress, dramatic'
      },
      {
        'prompt': 'Musician playing guitar on a street corner at dusk',
        'description': 'Street Performer',
        'tags': 'musician, guitar, street, dusk, performance'
      },
    ],
    'Fantasy': [
      {
        'prompt': 'Dragon soaring over a medieval castle with mountains in background',
        'description': 'Dragon & Castle',
        'tags': 'dragon, castle, medieval, mountains, fantasy'
      },
      {
        'prompt': 'Enchanted library with floating books and magical glowing orbs',
        'description': 'Magic Library',
        'tags': 'library, books, magic, glowing, enchanted'
      },
      {
        'prompt': 'Fairy village built inside giant mushrooms with twinkling lights',
        'description': 'Fairy Village',
        'tags': 'fairy, village, mushrooms, lights, magical'
      },
      {
        'prompt': 'Wizard casting spells with swirling magical energy around him',
        'description': 'Spell Casting',
        'tags': 'wizard, spells, magic, energy, fantasy'
      },
      {
        'prompt': 'Crystal cave with glowing gems and mysterious fog',
        'description': 'Crystal Cave',
        'tags': 'crystal, cave, gems, glowing, mysterious'
      },
      {
        'prompt': 'Phoenix rising from flames with golden feathers spread wide',
        'description': 'Phoenix Rising',
        'tags': 'phoenix, flames, golden, feathers, mythical'
      },
    ],
    'Sci-Fi': [
      {
        'prompt': 'Space station orbiting a distant planet with nebula in background',
        'description': 'Space Station',
        'tags': 'space, station, planet, nebula, orbit'
      },
      {
        'prompt': 'Robot walking through futuristic city with holographic displays',
        'description': 'Future City',
        'tags': 'robot, futuristic, city, holographic, displays'
      },
      {
        'prompt': 'Spaceship landing on alien planet with purple sky and twin moons',
        'description': 'Alien World',
        'tags': 'spaceship, alien, planet, purple sky, moons'
      },
      {
        'prompt': 'Cybernetic warrior with glowing implants in high-tech armor',
        'description': 'Cyber Warrior',
        'tags': 'cybernetic, warrior, implants, armor, tech'
      },
      {
        'prompt': 'Time machine laboratory with swirling energy portals',
        'description': 'Time Travel Lab',
        'tags': 'time machine, laboratory, portals, energy'
      },
      {
        'prompt': 'Underwater city dome with marine life swimming around',
        'description': 'Underwater City',
        'tags': 'underwater, city, dome, marine life, ocean'
      },
      {
        'prompt': 'AI consciousness represented as flowing digital streams of light',
        'description': 'Digital Consciousness',
        'tags': 'AI, consciousness, digital, streams, light'
      },
    ],
    'Abstract': [
      {
        'prompt': 'Fluid dynamic colors blending like liquid mercury',
        'description': 'Liquid Metal',
        'tags': 'fluid, colors, liquid, mercury, dynamic'
      },
      {
        'prompt': 'Geometric mandala with intricate patterns and gold accents',
        'description': 'Sacred Geometry',
        'tags': 'geometric, mandala, patterns, gold, sacred'
      },
      {
        'prompt': 'Explosion of paint in mid-air with vibrant color splashes',
        'description': 'Paint Explosion',
        'tags': 'explosion, paint, colors, splashes, vibrant'
      },
      {
        'prompt': 'Digital glitch art with fragmented reality and neon colors',
        'description': 'Glitch Art',
        'tags': 'digital, glitch, fragmented, neon, reality'
      },
      {
        'prompt': 'Flowing silk fabric in wind with ethereal lighting',
        'description': 'Ethereal Fabric',
        'tags': 'silk, fabric, wind, ethereal, flowing'
      },
      {
        'prompt': 'Crystalline structures growing in impossible formations',
        'description': 'Crystal Growth',
        'tags': 'crystalline, structures, growth, formations'
      },
    ],
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _promptCategories.keys.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _getFilteredPrompts(List<Map<String, String>> prompts) {
    if (_searchQuery.isEmpty) return prompts;
    
    return prompts.where((prompt) {
      final searchLower = _searchQuery.toLowerCase();
      return prompt['prompt']!.toLowerCase().contains(searchLower) ||
             prompt['description']!.toLowerCase().contains(searchLower) ||
             prompt['tags']!.toLowerCase().contains(searchLower);
    }).toList();
  }

  void _selectPrompt(String prompt) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(prompt);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final isDark = themeProvider.isDark;

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: AppColors.getSurface(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.2),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(isDark),
              _buildSearchBar(isDark),
              _buildTabBar(isDark),
              Expanded(child: _buildTabContent(isDark)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.getTextTertiary(isDark).withOpacity(0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText.bodyLarge(
                  'Prompt Suggestions',
                  color: AppColors.getTextPrimary(isDark),
                  fontWeight: FontWeight.w600,
                ),
                AppText.bodySmall(
                  'Choose a prompt to get started or find inspiration',
                  color: AppColors.getTextSecondary(isDark),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: AppColors.getTextSecondary(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppColors.getTextPrimary(isDark)),
        decoration: InputDecoration(
          hintText: 'Search prompts...',
          hintStyle: TextStyle(color: AppColors.getTextTertiary(isDark)),
          prefixIcon: Icon(
            Icons.search,
            color: AppColors.getTextTertiary(isDark),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: Icon(
                    Icons.clear,
                    color: AppColors.getTextTertiary(isDark),
                  ),
                )
              : null,
          filled: true,
          fillColor: AppColors.getBackground(isDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppColors.getTextTertiary(isDark).withOpacity(0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary),
          ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.getTextTertiary(isDark).withOpacity(0.1),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: AppColors.primary,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.getTextSecondary(isDark),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        tabs: _promptCategories.keys.map((category) => Tab(
          text: category,
        )).toList(),
      ),
    );
  }

  Widget _buildTabContent(bool isDark) {
    return TabBarView(
      controller: _tabController,
      children: _promptCategories.entries.map((entry) {
        final category = entry.key;
        final prompts = _getFilteredPrompts(entry.value);
        
        if (prompts.isEmpty && _searchQuery.isNotEmpty) {
          return _buildEmptySearch(isDark);
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: prompts.length,
          itemBuilder: (context, index) {
            final prompt = prompts[index];
            return _buildPromptCard(prompt, isDark);
          },
        );
      }).toList(),
    );
  }

  Widget _buildPromptCard(Map<String, String> promptData, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.getBackground(isDark),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.getTextTertiary(isDark).withOpacity(0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _selectPrompt(promptData['prompt']!),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: AppText.bodySmall(
                        promptData['description']!,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: AppColors.getTextTertiary(isDark),
                      size: 14,
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                AppText.bodyMedium(
                  promptData['prompt']!,
                  color: AppColors.getTextPrimary(isDark),
                  fontWeight: FontWeight.w500,
                  maxLines: 3,
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      color: AppColors.getTextTertiary(isDark),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: AppText.bodySmall(
                        promptData['tags']!,
                        color: AppColors.getTextTertiary(isDark),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySearch(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.getTextTertiary(isDark).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off,
                color: AppColors.getTextTertiary(isDark),
                size: 32,
              ),
            ),
            
            const SizedBox(height: 16),
            
            AppText.bodyMedium(
              'No prompts found',
              color: AppColors.getTextPrimary(isDark),
              fontWeight: FontWeight.w600,
            ),
            
            const SizedBox(height: 8),
            
            AppText.bodySmall(
              'Try searching with different keywords or browse other categories',
              color: AppColors.getTextSecondary(isDark),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 16),
            
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: Text(
                'Clear Search',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}