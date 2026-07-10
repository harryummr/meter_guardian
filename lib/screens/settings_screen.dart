import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dailyReminder = false;
  bool _weeklyReminder = false;

  Future<void> _toggleDaily(bool value) async {
    setState(() => _dailyReminder = value);
    if (value) {
      await NotificationService.instance.scheduleDailyReminder();
    }
  }

  Future<void> _toggleWeekly(bool value) async {
    setState(() => _weeklyReminder = value);
    if (value) {
      await NotificationService.instance.scheduleWeeklyReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle: const Text('Nudge to scan today\'s reading, 8 PM'),
            value: _dailyReminder,
            onChanged: _toggleDaily,
          ),
          SwitchListTile(
            title: const Text('Weekly summary reminder'),
            subtitle: const Text('Sunday evening check-in'),
            value: _weeklyReminder,
            onChanged: _toggleWeekly,
          ),
          const Divider(),
          const ListTile(
            title: Text('About Meter Guardian'),
            subtitle: Text(
              'All data stays on this device. OCR runs fully offline using Google ML Kit '
              '— no images or readings are ever uploaded anywhere.',
            ),
          ),
        ],
      ),
    );
  }
}
