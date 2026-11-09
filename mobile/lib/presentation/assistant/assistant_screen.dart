import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/formatters.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../data/photos/photo_capture.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/assistant_api.dart';
import '../../data/remote/online_status.dart';
import '../../domain/assistant_tips.dart';
import '../../domain/entities.dart';
import '../../domain/repositories.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/fade_in.dart';
import '../widgets/motion.dart';
import '../widgets/notice_box.dart';
import 'assistant_cubit.dart';

/// Chat con el asistente sobre una vaca. Aviso fijo: orienta, no diagnostica. Sin internet muestra
/// un banner y consejos fijos.
class AssistantScreen extends StatelessWidget {
  const AssistantScreen({super.key, required this.cow});

  final Cow cow;

  @override
  Widget build(BuildContext context) {
    final status = context.read<OnlineStatus>();
    return BlocProvider(
      create: (context) => AssistantCubit(
        cowId: cow.id,
        api: AssistantApi(context.read<ApiClient>()),
        messages: context.read<AssistantRepository>(),
        records: context.read<RecordRepository>(),
        inferences: context.read<InferenceRepository>(),
        capture: context.read<PhotoCapture>(),
        connectivity: status.changes,
        initiallyOnline: status.online,
      ),
      child: _AssistantView(cow: cow),
    );
  }
}

class _AssistantView extends StatefulWidget {
  const _AssistantView({required this.cow});

  final Cow cow;

  @override
  State<_AssistantView> createState() => _AssistantViewState();
}

class _AssistantViewState extends State<_AssistantView> {
  final _question = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _question.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (await context.read<AssistantCubit>().send(_question.text)) _question.clear();
  }

  Future<void> _attach() async {
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera, size: 32),
              title: const Text('Tomar foto de la ubre'),
              onTap: () => Navigator.pop(context, PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 32),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(context, PhotoSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null && mounted) await context.read<AssistantCubit>().attachPhoto(source);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppScaffold(
      title: 'Asistente · ${widget.cow.name ?? widget.cow.tag}',
      body: Column(
        children: [
          // Aviso fijo, siempre visible
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.notice,
            child: Row(
              children: [
                const Icon(Icons.smart_toy, color: AppColors.onNotice),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(AssistantTips.notice,
                      style: theme.textTheme.titleSmall?.copyWith(color: AppColors.onNotice)),
                ),
              ],
            ),
          ),
          BlocBuilder<AssistantCubit, AssistantState>(
            buildWhen: (previous, current) => previous.online != current.online,
            builder: (context, state) => state.online
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: AppColors.demoBanner,
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off, color: AppColors.onDemoBanner),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('Sin internet: el asistente no está disponible. Abajo hay consejos básicos.',
                              style: theme.textTheme.banner.copyWith(color: AppColors.onDemoBanner)),
                        ),
                      ],
                    ),
                  ),
          ),
          Expanded(
            child: StreamBuilder<List<AssistantMessage>>(
              stream: context.read<AssistantRepository>().watchMessages(widget.cow.id),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? const <AssistantMessage>[];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
                });
                return BlocBuilder<AssistantCubit, AssistantState>(
                  builder: (context, state) => ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      CenteredContent(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (messages.isEmpty && state.online)
                              Text(
                                'Pregunte sobre esta vaca: qué revisar, cómo cuidar el ordeño o cuándo llamar al '
                                'veterinario. Puede adjuntar una foto de la ubre.',
                                style: theme.textTheme.bodyLarge,
                              ),
                            for (final message in messages) _Bubble(message: message),
                            if (state.sending) const _Typing(),
                            if (state.error != null) ...[
                              const SizedBox(height: 8),
                              NoticeBox.error(state.error!),
                            ],
                            if (!state.online) ...[
                              const SizedBox(height: 12),
                              const _OfflineTips(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          BlocBuilder<AssistantCubit, AssistantState>(
            builder: (context, state) => SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: CenteredContent(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.photo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.small),
                                child: Image.memory(state.photo!, width: 56, height: 56, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(child: Text('Foto lista para enviar (sin ubicación)')),
                              IconButton(
                                tooltip: 'Quitar foto',
                                icon: const Icon(Icons.close),
                                onPressed: context.read<AssistantCubit>().removePhoto,
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Adjuntar foto',
                            iconSize: 32,
                            icon: const Icon(Icons.add_a_photo),
                            onPressed: state.online && !state.sending ? _attach : null,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _question,
                              enabled: state.online,
                              minLines: 1,
                              maxLines: 4,
                              maxLength: 1000,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: const InputDecoration(hintText: 'Escriba su pregunta', counterText: ''),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Enviar',
                            iconSize: 32,
                            icon: const Icon(Icons.send),
                            onPressed: state.online && !state.sending ? _send : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.fromUser;
    final ink = mine ? AppColors.onPrimary : AppColors.ink;
    const big = Radius.circular(AppRadius.large);
    const small = Radius.circular(4);
    return FadeIn(
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: mine ? AppColors.primary : AppColors.surface,
            border: mine ? null : Border.all(color: AppColors.cardBorder),
            // La punta de la burbuja apunta hacia quien habla
            borderRadius: BorderRadius.only(
              topLeft: big,
              topRight: big,
              bottomLeft: mine ? big : small,
              bottomRight: mine ? small : big,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.withPhoto)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.photo, size: 18, color: ink),
                    const SizedBox(width: 4),
                    Text('Con foto', style: theme.textTheme.bodySmall?.copyWith(color: ink)),
                  ]),
                ),
              Text(message.text, style: theme.textTheme.bodyLarge?.copyWith(color: ink)),
              const SizedBox(height: 4),
              Text(
                '${mine ? 'Usted' : 'Asistente'} · ${formatDateTime(message.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          label: 'El asistente está respondiendo',
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.cardBorder),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.large),
                topRight: Radius.circular(AppRadius.large),
                bottomRight: Radius.circular(AppRadius.large),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const TypingDots(),
          ),
        ),
      );
}

class _OfflineTips extends StatelessWidget {
  const _OfflineTips();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (title, tips) in AssistantTips.offline) ...[
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              for (final tip in tips)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(Icons.check, size: 20, color: AppColors.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tip, style: theme.textTheme.bodyLarge)),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
