import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

const recoveryClipboardLifetime = Duration(minutes: 1);

typedef RecoveryClipboardReader = Future<String?> Function();
typedef RecoveryClipboardWriter = Future<void> Function(String text);

Future<void> copyRecoveryKeyToClipboard(
  String recoveryKey, {
  Duration clearAfter = recoveryClipboardLifetime,
  RecoveryClipboardReader? readClipboard,
  RecoveryClipboardWriter? writeClipboard,
}) async {
  final reader = readClipboard ?? _readSystemClipboard;
  final writer = writeClipboard ?? _writeSystemClipboard;

  await writer(recoveryKey);

  Timer(clearAfter, () {
    unawaited(
      _clearRecoveryKeyIfUnchanged(
        recoveryKey,
        readClipboard: reader,
        writeClipboard: writer,
      ),
    );
  });
}

Future<String?> _readSystemClipboard() async {
  return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
}

Future<void> _writeSystemClipboard(String text) {
  return Clipboard.setData(ClipboardData(text: text));
}

Future<void> _clearRecoveryKeyIfUnchanged(
  String recoveryKey, {
  required RecoveryClipboardReader readClipboard,
  required RecoveryClipboardWriter writeClipboard,
}) async {
  final current = await readClipboard();
  if (current != recoveryKey) return;
  await writeClipboard('');
}

/// Shows a server-issued recovery key exactly once during signup.
///
/// The key is intentionally not persisted by this widget. The user must save
/// it somewhere they control before continuing into the app.
Future<void> showRecoveryKeyDialog({
  required BuildContext context,
  required String recoveryKey,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: PyreColors.paper,
          title: const Text(
            'Save your recovery key',
            style: TextStyle(
              color: PyreColors.onPaper,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Keep this somewhere only you can access. PyreChat is not saving this key in local app storage.',
                  style: TextStyle(color: PyreColors.onPaperMuted),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PyreColors.paperDim,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    recoveryKey,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: PyreColors.onPaper,
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Do not send this key to anyone claiming to be PyreChat support.',
                  style: TextStyle(
                    color: PyreColors.onPaperMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await copyRecoveryKeyToClipboard(recoveryKey);
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Recovery key copied — clipboard clears in 60 seconds',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy key'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("I've saved it"),
            ),
          ],
        ),
      );
    },
  );
}
