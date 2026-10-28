import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(strokeWidth: 5),
                const SizedBox(height: 24),
                Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ),
      );
}
