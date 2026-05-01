import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/settings_model.dart';
import 'language_selector_sheet.dart';

class LanguageSettingItem extends StatelessWidget {
  const LanguageSettingItem({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.watch<SettingsModel>();
    final selectedLanguageName = AppLocalizations.languageNameForPreference(
      settings.localePreference,
      l10n,
    );

    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.cyan.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.language, color: Colors.cyan, size: 24),
        ),
        title: Text(
          l10n.settingsLanguageTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '${l10n.settingsLanguageSubtitle} · $selectedLanguageName',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white24),
        onTap: () => LanguageSelectorSheet.show(context),
      ),
    );
  }
}
