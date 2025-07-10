import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Bot Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Choose your AI Persona',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          RadioListTile(
            title: const Text('No Persona (Default)'),
            value: 'none',
            groupValue: settingsProvider.persona,
            onChanged: (value) => settingsProvider.setPersona(value!),
          ),
          RadioListTile(
            title: const Text('Friendly Assistant'),
            value: 'friendly',
            groupValue: settingsProvider.persona,
            onChanged: (value) => settingsProvider.setPersona(value!),
          ),
          RadioListTile(
            title: const Text('Professional Expert'),
            value: 'professional',
            groupValue: settingsProvider.persona,
            onChanged: (value) => settingsProvider.setPersona(value!),
          ),
          RadioListTile(
            title: const Text('Funny Buddy'),
            value: 'funny',
            groupValue: settingsProvider.persona,
            onChanged: (value) => settingsProvider.setPersona(value!),
          ),
        ],
      ),
    );
  }
}
