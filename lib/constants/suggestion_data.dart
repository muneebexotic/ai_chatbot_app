import 'package:flutter/material.dart';

// The 'Create Image' and 'Generate Images' chips were removed here.
//
// Image generation is cut by PRD §2.2 and banned outright by §16. The
// generation code went in Milestone 1, but these two chips survived it and
// kept offering the feature on the chat empty state — the first screen a
// signed-in user sees. Tapping one sent its prompt to a text model, which
// answered by describing a picture it had not made.
//
// Found by looking at a device screenshot, not by reading code: nothing
// referenced the deleted services, so nothing failed to compile and no test
// covered the contents of this list.
//
// Image *understanding* (§5.4) is a different feature and arrives with the
// gateway in Milestone 3. It does not belong here either until it exists.

final List<Map<String, dynamic>> suggestionChipData = [
  {
    'label': 'Brainstorm',
    'icon': Icons.lightbulb_outline,
    'suggestions': [
      'Help me brainstorm ideas for a new project',
      'Generate creative solutions for problem-solving',
      'What are some innovative approaches to marketing',
      'Brainstorm unique business name ideas',
    ],
  },
  {
    'label': 'Get Advice',
    'icon': Icons.psychology_outlined,
    'suggestions': [
      'Give me advice on career development',
      'How to improve my communication skills',
      'Tips for maintaining work-life balance',
      'Advice on building healthy relationships',
    ],
  },
  {
    'label': 'Make a Plan',
    'icon': Icons.calendar_today_outlined,
    'suggestions': [
      'Create a 30-day fitness plan',
      'Plan a weekend trip itinerary',
      'Make a study schedule for exams',
      'Design a meal prep plan for the week',
    ],
  },
  {
    'label': 'Surprise Me',
    'icon': Icons.auto_awesome_outlined,
    'suggestions': [
      'Tell me an interesting random fact',
      'Share a fun riddle or brain teaser',
      'Recommend something new to try today',
      'Give me a creative writing prompt',
    ],
  },
  {
    'label': 'Help Me Write',
    'icon': Icons.edit_outlined,
    'suggestions': [
      'Write a professional email template',
      'Help me draft a resume summary',
      'Create a compelling story opening',
      'Write a persuasive product description',
    ],
  },
  {
    'label': 'Pamper Me',
    'icon': Icons.spa_outlined,
    'suggestions': [
      'Suggest a relaxing evening routine',
      'Recommend self-care activities',
      'Create a meditation script',
      'Give me compliments and motivation',
    ],
  },
];
