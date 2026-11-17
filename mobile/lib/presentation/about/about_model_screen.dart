import 'package:flutter/material.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/model_facts.dart';
import '../widgets/app_scaffold.dart';

/// "Acerca del modelo": qué hay detrás del semáforo y de las lecturas experimentales, con las cifras
/// de los informes del proyecto. Solo texto.
class AboutModelScreen extends StatelessWidget {
  const AboutModelScreen({super.key});

  static const title = 'Acerca del modelo';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          CenteredContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  key: const Key('about-disclaimer'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.highlightSurface,
                    border: Border.all(color: AppColors.highlightBorder),
                    borderRadius: AppRadius.field,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.warningText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ModelFacts.disclaimer,
                          style: theme.textTheme.titleSmall?.copyWith(color: AppColors.warningText),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final section in ModelFacts.sections) ...[
                  const SizedBox(height: 20),
                  Text(section.title, style: theme.textTheme.titleLarge),
                  for (final paragraph in section.paragraphs) ...[
                    const SizedBox(height: 8),
                    Text(paragraph, style: theme.textTheme.bodyLarge),
                  ],
                  if (section.facts.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            for (final fact in section.facts)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 3, child: Text(fact.label, style: theme.textTheme.bodyLarge)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        fact.value,
                                        textAlign: TextAlign.end,
                                        style: theme.textTheme.titleSmall,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  for (final note in section.notes) ...[
                    const SizedBox(height: 8),
                    Text(note, style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted)),
                  ],
                ],
                const SizedBox(height: 20),
                Text(ModelFacts.disclaimer, style: theme.textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
