import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

Future<bool> confirmLogout(
  BuildContext context, {
  required int draftCount,
}) async {
  final draftMessage = switch (draftCount) {
    0 => 'You can sign back in at any time.',
    1 =>
      'You have 1 unsent draft. Logging out will clear it from this device.',
    _ =>
      'You have $draftCount unsent drafts. Logging out will clear them from this device.',
  };

  final logout = await showDialog<bool>(
    context: context,
    barrierColor: PyreColors.dialogScrim,
    builder: (context) => AlertDialog(
      backgroundColor: PyreColors.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text(
        'Log out of PyreChat?',
        style: TextStyle(
          color: PyreColors.paper,
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Text(
        draftMessage,
        style: const TextStyle(color: PyreColors.mute),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: PyreColors.paper,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(
            'Log out',
            style: TextStyle(
              color: PyreColors.ember,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );

  return logout == true;
}
