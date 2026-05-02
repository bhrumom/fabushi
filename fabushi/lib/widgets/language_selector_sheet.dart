import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/settings_model.dart';

class LanguageSelectorSheet extends StatelessWidget {
  const LanguageSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const LanguageSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = context.watch<SettingsModel>();

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Icon(Icons.language, color: Colors.cyan),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.languageChooserTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.cancel,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: AppLocalizations.languageOptions.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: Colors.white10,
                  indent: 20,
                  endIndent: 20,
                ),
                itemBuilder: (context, index) {
                  final option = AppLocalizations.languageOptions[index];
                  final isSystem =
                      option.code == AppLocalizations.systemLocaleCode;
                  return RadioListTile<String>(
                    value: option.code,
                    groupValue: settings.localePreference,
                    activeColor: Colors.cyan,
                    onChanged: (value) async {
                      if (value == null) {
                        return;
                      }
                      await settings.setLocalePreference(value);
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    title: Text(
                      isSystem ? l10n.languageSystem : option.nativeName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      isSystem
                          ? l10n.languageSystemDescription
                          : option.englishName,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
