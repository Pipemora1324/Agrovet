import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../domain/privacy_notice.dart';

/// Texto completo del aviso de privacidad (Ley 1581 de 2012).
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(PrivacyNotice.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CenteredContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Versión ${PrivacyNotice.version}', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    'Al crear la cuenta usted autoriza el tratamiento de sus datos personales según la '
                    'Ley 1581 de 2012, en los términos de este aviso.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  for (final (title, paragraphs) in PrivacyNotice.sections) ...[
                    const SizedBox(height: 20),
                    Text(title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 6),
                    for (final paragraph in paragraphs)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.circle, size: 8, color: theme.colorScheme.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(paragraph, style: theme.textTheme.bodyLarge)),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
