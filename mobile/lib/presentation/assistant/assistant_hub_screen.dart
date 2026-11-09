import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../domain/assistant_tips.dart';
import '../../domain/repositories.dart';
import '../cows/cows_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/fade_in.dart';
import '../widgets/motion.dart';
import 'assistant_screen.dart';

/// Pestaña "Asistente": el ganadero elige sobre qué vaca quiere preguntar.
class AssistantHubScreen extends StatelessWidget {
  const AssistantHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Asistente',
      body: StreamBuilder<List<CowSummary>>(
        stream: context.read<CowRepository>().watchCows(),
        builder: (context, snapshot) {
          final cows = snapshot.data ?? const <CowSummary>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CenteredContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeIn(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.card),
                        child: Row(
                          children: [
                            const Icon(Icons.smart_toy, size: 40, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('¿Sobre qué vaca quiere preguntar?', style: theme.textTheme.titleMedium),
                                  const SizedBox(height: 4),
                                  Text(AssistantTips.notice, style: theme.textTheme.bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (snapshot.connectionState == ConnectionState.waiting && cows.isEmpty)
                      const Center(child: CircularProgressIndicator())
                    else if (cows.isEmpty)
                      Text('Agregue una vaca en la pestaña "Vacas" para conversar sobre ella.',
                          style: theme.textTheme.bodyLarge)
                    else
                      for (var i = 0; i < cows.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: FadeIn(
                            index: i + 1,
                            child: PressScale(
                              child: Card(
                                clipBehavior: Clip.antiAlias,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CowAvatar(level: cows[i].lastRisk, size: 48),
                                  title: Text(cows[i].cow.name ?? cows[i].cow.tag),
                                  subtitle: Text(cows[i].cow.tag),
                                  trailing: const Icon(Icons.chat, color: AppColors.primary),
                                  onTap: () => Navigator.push(context,
                                      MaterialPageRoute(builder: (_) => AssistantScreen(cow: cows[i].cow))),
                                ),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
