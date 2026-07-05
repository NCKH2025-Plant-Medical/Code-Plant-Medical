import 'package:flutter/material.dart';
import 'package:thunghiem1/app.dart';

class SettingScreen extends StatelessWidget {
  const SettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ThemeScope.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Appearance',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _ThemeModeTile(
                  title: 'System default',
                  subtitle: 'Follow device theme',
                  icon: Icons.brightness_auto,
                  value: ThemeMode.system,
                  groupValue: themeNotifier.themeMode,
                  onChanged: themeNotifier.setThemeMode,
                ),
                const Divider(height: 1),
                _ThemeModeTile(
                  title: 'Light',
                  subtitle: 'Always use light theme',
                  icon: Icons.light_mode,
                  value: ThemeMode.light,
                  groupValue: themeNotifier.themeMode,
                  onChanged: themeNotifier.setThemeMode,
                ),
                const Divider(height: 1),
                _ThemeModeTile(
                  title: 'Dark',
                  subtitle: 'Always use dark theme',
                  icon: Icons.dark_mode,
                  value: ThemeMode.dark,
                  groupValue: themeNotifier.themeMode,
                  onChanged: themeNotifier.setThemeMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  const _ThemeModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ThemeMode value;
  final ThemeMode groupValue;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = value == groupValue;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Radio<ThemeMode>(
        value: value,
        groupValue: groupValue,
        onChanged: (mode) {
          if (mode != null) onChanged(mode);
        },
      ),
      onTap: () => onChanged(value),
    );
  }
}
