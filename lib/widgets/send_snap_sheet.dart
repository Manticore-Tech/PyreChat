import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';

Future<bool> showSendSnapSheet({
  required BuildContext context,
  required Uint8List imageBytes,
  String? conversationId,
  List<String>? recipientIds,
  String? recipientLabel,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: PyreColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _SendSnapSheet(
      imageBytes: imageBytes,
      conversationId: conversationId,
      recipientIds: recipientIds,
      recipientLabel: recipientLabel,
    ),
  );
  return sent == true;
}

class _SendSnapSheet extends StatefulWidget {
  const _SendSnapSheet({
    required this.imageBytes,
    this.conversationId,
    this.recipientIds,
    this.recipientLabel,
  });

  final Uint8List imageBytes;
  final String? conversationId;
  final List<String>? recipientIds;
  final String? recipientLabel;

  @override
  State<_SendSnapSheet> createState() => _SendSnapSheetState();
}

class _SendSnapSheetState extends State<_SendSnapSheet> {
  final _client = PyreClient();
  final _caption = TextEditingController();
  final _selected = <String>{};

  List<PyreFriend> _friends = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.recipientIds != null && widget.recipientIds!.isNotEmpty) {
      setState(() {
        _selected.addAll(widget.recipientIds!);
        _loading = false;
      });
      return;
    }
    try {
      final friends = await _client.friends();
      if (!mounted) return;
      setState(() {
        _friends = friends;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load friends';
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) return;
    setState(() => _sending = true);
    try {
      final mediaKey = await _client.uploadMedia(widget.imageBytes);
      await _client.sendSnap(
        mediaKey: mediaKey,
        recipientIds: _selected.toList(growable: false),
        caption: _caption.text.trim(),
        conversationId: widget.conversationId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on PyreApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send Pyre')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = media.padding.bottom;
    final keyboard = media.viewInsets.bottom;
    final directTarget = widget.recipientIds?.isNotEmpty == true;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          const Text(
            'Send Pyre',
            style: TextStyle(
              color: PyreColors.paper,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(
              widget.imageBytes,
              height: 120,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _caption,
            style: const TextStyle(color: PyreColors.paper),
            decoration: InputDecoration(
              hintText: 'Add a caption',
              hintStyle: TextStyle(
                color: PyreColors.mute.withValues(alpha: 0.9),
              ),
              filled: true,
              fillColor: PyreColors.ink,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Send to',
            style: TextStyle(
              color: PyreColors.mute,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: CircularProgressIndicator(color: PyreColors.ember),
              ),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: PyreColors.mute))
          else if (directTarget)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: PyreColors.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline,
                    color: PyreColors.ember,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Direct to ${widget.recipientLabel ?? 'this chat'}',
                      style: const TextStyle(
                        color: PyreColors.paper,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_friends.isEmpty)
            const Text(
              'Add friends first to send a Pyre.',
              style: TextStyle(
                color: PyreColors.mute,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.builder(
                itemCount: _friends.length,
                itemBuilder: (context, i) {
                  final f = _friends[i];
                  final on = _selected.contains(f.id);
                  return CheckboxListTile(
                    value: on,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(f.id);
                        } else {
                          _selected.remove(f.id);
                        }
                      });
                    },
                    activeColor: PyreColors.ember,
                    title: Text(
                      f.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PyreColors.paper,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '@${f.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: PyreColors.mute),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _sending || _selected.isEmpty ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: PyreColors.ember,
              foregroundColor: PyreColors.paper,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _sending ? 'Sending…' : 'Send Pyre',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}
