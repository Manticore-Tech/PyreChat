import 'package:flutter/material.dart';
import 'package:pyrechat_flutter/models/session.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_glass_surface.dart';
import 'package:pyrechat_flutter/widgets/pyre_night_backdrop.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, this.client});

  final PyreClient? client;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  late final PyreClient _client;
  List<PyreSession> _sessions = const [];
  bool _loading = true;
  String? _error;
  String? _revokingId;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PyreClient();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final sessions = await _client.sessions();
      if (!mounted) return;
      setState(() {
        _sessions = _orderSessions(sessions);
        _loading = false;
      });
    } on PyreApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.safeSessionMessage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load signed-in devices.';
        _loading = false;
      });
    }
  }

  List<PyreSession> _orderSessions(Iterable<PyreSession> sessions) {
    final ordered = sessions.toList(growable: true);
    ordered.sort((a, b) {
      if (a.current != b.current) return a.current ? -1 : 1;

      final aCreated = a.createdAt;
      final bCreated = b.createdAt;
      if (aCreated != null && bCreated != null) {
        final newestFirst = bCreated.compareTo(aCreated);
        if (newestFirst != 0) return newestFirst;
      } else if (aCreated != null) {
        return -1;
      } else if (bCreated != null) {
        return 1;
      }

      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return List<PyreSession>.unmodifiable(ordered);
  }

  Future<void> _revoke(PyreSession session) async {
    if (session.current || _revokingId != null) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            final expires = _expiryLabel(session.expiresAt);
            return AlertDialog(
              backgroundColor: PyreColors.paper,
              scrollable: true,
              title: const Text(
                'Sign out this session?',
                style: TextStyle(
                  color: PyreColors.onPaper,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.label,
                    style: const TextStyle(
                      color: PyreColors.onPaper,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dateLabel(session.createdAt),
                    style: const TextStyle(color: PyreColors.onPaperMuted),
                  ),
                  if (expires != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      expires,
                      style: const TextStyle(color: PyreColors.onPaperMuted),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'This signs that session out immediately.',
                    style: TextStyle(color: PyreColors.onPaperMuted),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Sign out'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) return;

    setState(() => _revokingId = session.id);
    try {
      await _client.revokeSession(session.id);
      if (!mounted) return;
      setState(() {
        _sessions = _sessions
            .where((candidate) => candidate.id != session.id)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session signed out.')),
      );
    } on PyreApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.safeSessionMessage)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out that session.')),
      );
    } finally {
      if (mounted) setState(() => _revokingId = null);
    }
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Sign-in time unavailable';
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return 'Signed in ${local.year}-$month-$day at $hour:$minute';
  }

  String? _expiryLabel(DateTime? value) {
    if (value == null) return null;
    final local = value.toLocal();
    final now = DateTime.now();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    if (!local.isAfter(now)) {
      return 'Expired';
    }

    final today = DateTime(now.year, now.month, now.day);
    final expiryDay = DateTime(local.year, local.month, local.day);
    final dayOffset = expiryDay.difference(today).inDays;
    if (dayOffset == 0) return 'Expires today at $hour:$minute';
    if (dayOffset == 1) return 'Expires tomorrow at $hour:$minute';

    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return 'Expires ${local.year}-$month-$day at $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: PyreColors.night,
      body: PyreNightBackdrop(
        mood: PyreSurfaceMood.settings,
        showEmbers: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, top + 10, 18, 30),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back to settings',
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.05),
                    foregroundColor: PyreColors.nightText,
                  ),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Signed-in devices',
                    style: TextStyle(
                      color: PyreColors.nightText,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loading || _revokingId != null ? null : _load,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: PyreColors.nightText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Review where your account is signed in. Signing out another session takes effect immediately.',
              style: TextStyle(
                color: PyreColors.nightMuted,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            if (_loading)
              Semantics(
                liveRegion: true,
                label: 'Loading signed-in devices',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: PyreColors.emberGlow,
                      ),
                    ),
                  ),
                ),
              )
            else if (_error != null)
              PyreGlassSurface(
                tone: PyreGlassTone.standard,
                radius: 20,
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Semantics(
                      liveRegion: true,
                      label: 'Signed-in devices error: ${_error!}',
                      child: ExcludeSemantics(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: PyreColors.nightText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _load,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (_sessions.isEmpty)
              PyreGlassSurface(
                tone: PyreGlassTone.standard,
                radius: 20,
                padding: EdgeInsets.all(18),
                child: Text(
                  'No active sessions were returned.',
                  style: TextStyle(
                    color: PyreColors.nightMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              ..._sessions.map(
                (session) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SessionCard(
                    session: session,
                    createdLabel: _dateLabel(session.createdAt),
                    expiresLabel: _expiryLabel(session.expiresAt),
                    busy: _revokingId == session.id,
                    onRevoke: session.current ? null : () => _revoke(session),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.createdLabel,
    required this.expiresLabel,
    required this.busy,
    this.onRevoke,
  });

  final PyreSession session;
  final String createdLabel;
  final String? expiresLabel;
  final bool busy;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return PyreGlassSurface(
      tone: session.current ? PyreGlassTone.strong : PyreGlassTone.standard,
      radius: 20,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: PyreColors.ember.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.devices_rounded,
                color: PyreColors.emberGlow,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Semantics(
                        container: true,
                        label: session.current ? '${session.label}, this device' : session.label,
                        child: ExcludeSemantics(
                          child: Text(
                            session.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PyreColors.nightText,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (session.current) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: PyreColors.ember.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'THIS DEVICE',
                          style: TextStyle(
                            color: PyreColors.emberGlow,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  createdLabel,
                  style: const TextStyle(
                    color: PyreColors.nightMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (expiresLabel case final expires?) ...[
                  const SizedBox(height: 2),
                  Text(
                    expires,
                    style: const TextStyle(
                      color: PyreColors.nightMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onRevoke != null) ...[
            const SizedBox(width: 10),
            Semantics(
              container: true,
              button: true,
              enabled: !busy,
              liveRegion: busy,
              label: busy
                  ? 'Signing out ${session.label}'
                  : 'Sign out ${session.label}',
              onTap: busy ? null : onRevoke,
              child: ExcludeSemantics(
                child: TextButton(
                  onPressed: busy ? null : onRevoke,
                  child: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign out'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
