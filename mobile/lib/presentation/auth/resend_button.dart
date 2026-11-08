import 'dart:async';

import 'package:flutter/material.dart';

/// Botón "Reenviar código" con cuenta regresiva hasta que el servidor permita otro envío.
class ResendButton extends StatefulWidget {
  const ResendButton({super.key, required this.availableAt, required this.onPressed, this.busy = false});

  final DateTime availableAt;
  final VoidCallback onPressed;
  final bool busy;

  @override
  State<ResendButton> createState() => _ResendButtonState();
}

class _ResendButtonState extends State<ResendButton> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(ResendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableAt != widget.availableAt) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (_remaining() > Duration.zero) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remaining() <= Duration.zero) timer.cancel();
        setState(() {});
      });
    }
  }

  Duration _remaining() {
    final left = widget.availableAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _format(Duration value) {
    final seconds = (value.inMilliseconds / 1000).ceil();
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _remaining();
    final waiting = remaining > Duration.zero;
    return TextButton.icon(
      onPressed: waiting || widget.busy ? null : widget.onPressed,
      icon: Icon(waiting ? Icons.hourglass_bottom : Icons.refresh),
      label: Text(waiting ? 'Reenviar código en ${_format(remaining)}' : 'Reenviar código'),
    );
  }
}
