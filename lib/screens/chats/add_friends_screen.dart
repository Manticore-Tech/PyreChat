import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pyrechat_flutter/models/friend.dart';
import 'package:pyrechat_flutter/models/friend_adds.dart';
import 'package:pyrechat_flutter/models/user.dart';
import 'package:pyrechat_flutter/services/pyre_api.dart';
import 'package:pyrechat_flutter/services/pyre_client.dart';
import 'package:pyrechat_flutter/theme/pyre_theme.dart';
import 'package:pyrechat_flutter/widgets/pyre_avatar.dart';

enum _AddFriendsPane { home, sent, hidden, ignored }

class AddFriendsScreen extends StatefulWidget {
  const AddFriendsScreen({
    super.key,
    this.client,
  });

  final PyreClient? client;

  @override
  State<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends State<AddFriendsScreen> {
  static const _homePreview = 8;

  late final PyreClient _client;
  final _searchCtrl = TextEditingController();

  FriendAddsBundle _bundle = const FriendAddsBundle(
    incoming: [],
    sent: [],
    hidden: [],
    deleted: [],
    suggestions: [],
  );
  List<PyreFriend> _hits = [];
  _AddFriendsPane _pane = _AddFriendsPane.home;
  bool _loading = true;
  bool _loadFailed = false;
  int _loadEpoch = 0;
  bool _searching = false;
  bool _searchFailed = false;
  String? _busyId;
  bool _showAllIncoming = false;
  Timer? _debounce;
  int _searchEpoch = 0;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? PyreClient();
    _load();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final epoch = ++_loadEpoch;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final bundle = await _client.friendAdds();
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _bundle = bundle;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted || epoch != _loadEpoch) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchCtrl.text.trim();
    final epoch = ++_searchEpoch;

    if (query.isEmpty) {
      setState(() {
        _hits = [];
        _searching = false;
        _searchFailed = false;
      });
      return;
    }

    // Invalidate visible results immediately, not after the debounce.
    setState(() {
      _hits = [];
      _searching = true;
      _searchFailed = false;
    });
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => _fetchSearch(query, epoch),
    );
  }

  Future<void> _fetchSearch(String query, int epoch) async {
    try {
      final hits = await _client.searchUsers(query);
      if (!mounted ||
          epoch != _searchEpoch ||
          _searchCtrl.text.trim() != query) {
        return;
      }
      setState(() {
        _hits = hits;
        _searching = false;
        _searchFailed = false;
      });
    } catch (_) {
      if (!mounted ||
          epoch != _searchEpoch ||
          _searchCtrl.text.trim() != query) {
        return;
      }
      setState(() {
        _hits = [];
        _searching = false;
        _searchFailed = true;
      });
    }
  }

  void _retrySearch() {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty || _searching) return;
    _debounce?.cancel();
    final epoch = ++_searchEpoch;
    setState(() {
      _hits = [];
      _searching = true;
      _searchFailed = false;
    });
    _fetchSearch(query, epoch);
  }

  Future<void> _run(String id, Future<void> Function() action) async {
    if (_busyId != null) return;
    setState(() => _busyId = id);
    try {
      await action();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final query = _searchCtrl.text.trim();
      if (query.isNotEmpty) {
        // A post-action refresh must not overwrite a newer typed search.
        _debounce?.cancel();
        final epoch = ++_searchEpoch;
        setState(() {
          _searching = true;
          _searchFailed = false;
        });
        await _fetchSearch(query, epoch);
      }
    } on PyreApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _add(PyreFriend friend) {
    return _run(friend.id, () async {
      final status = await _client.addFriend(userId: friend.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'accepted' ? 'You are friends!' : 'Request sent'),
        ),
      );
    });
  }

  Future<void> _inviteFriends() async {
    const text = 'Join me on Pyre Social — https://pyre.social';
    try {
      await Clipboard.setData(const ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite link copied')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not copy invite link. Try again.')),
      );
    }
  }

  void _openMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PyreColors.nightCardStrong,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: PyreColors.nightMuted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              _MenuRow(
                title: 'Sent requests',
                subtitle: '${_bundle.sent.length} waiting',
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pane = _AddFriendsPane.sent;
                    _searchCtrl.clear();
                  });
                },
              ),
              _MenuRow(
                title: 'Hidden suggestions',
                subtitle: '${_bundle.hidden.length} hidden',
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pane = _AddFriendsPane.hidden;
                    _searchCtrl.clear();
                  });
                },
              ),
              _MenuRow(
                title: 'Ignored requests',
                subtitle: '${_bundle.deleted.length} ignored',
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pane = _AddFriendsPane.ignored;
                    _searchCtrl.clear();
                  });
                },
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.07),
                    foregroundColor: PyreColors.nightText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _title => switch (_pane) {
        _AddFriendsPane.home => 'Add Friends',
        _AddFriendsPane.sent => 'Sent',
        _AddFriendsPane.hidden => 'Hidden',
        _AddFriendsPane.ignored => 'Ignored',
      };

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final searching = query.isNotEmpty;
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: PyreColors.night,
      body: ColoredBox(
        color: PyreColors.night,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, top + 8, 8, 2),
            child: Row(
              children: [
                IconButton(
                  tooltip: _pane == _AddFriendsPane.home ? 'Close' : 'Back',
                  onPressed: () {
                    if (_pane == _AddFriendsPane.home) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() => _pane = _AddFriendsPane.home);
                    }
                  },
                  icon: Icon(
                    _pane == _AddFriendsPane.home
                        ? Icons.close_rounded
                        : Icons.arrow_back_rounded,
                    size: 24,
                  ),
                  style: IconButton.styleFrom(foregroundColor: PyreColors.nightText),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _title,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      color: PyreColors.nightText,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.55,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Friend request options',
                  onPressed: _openMenu,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: PyreColors.nightText,
                    size: 23,
                  ),
                  style: IconButton.styleFrom(foregroundColor: PyreColors.nightText),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(
                color: PyreColors.nightText,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Search username',
                hintStyle: const TextStyle(
                  color: PyreColors.nightMuted,
                  fontWeight: FontWeight.w600,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  color: PyreColors.nightMuted,
                ),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.close_rounded),
                        color: PyreColors.nightMuted,
                        onPressed: _searchCtrl.clear,
                      ),
                suffixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.045),
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: PyreColors.emberGlow.withValues(alpha: 0.55),
                  ),
                ),
              ),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
            ),
          ),
          if (_pane == _AddFriendsPane.home && !searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Material(
                color: Colors.white.withValues(alpha: 0.035),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _inviteFriends,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.mail_outline_rounded,
                          size: 20,
                          color: PyreColors.nightText,
                        ),
                        const SizedBox(width: 8),
                        const Flexible(
                          child: Text(
                            'Invite your friends!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: PyreColors.nightText,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _body(searching: searching)),
          ],
        ),
      ),
    );
  }

  Widget _body({required bool searching}) {
    if (_searching || (!searching && _loading)) {
      return Center(
        child: Semantics(
          liveRegion: true,
          label: _searching ? 'Searching usernames' : 'Loading friend requests',
          child: const ExcludeSemantics(
            child: CircularProgressIndicator(color: PyreColors.emberGlow),
          ),
        ),
      );
    }

    if (!searching && _loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: PyreColors.nightMuted, size: 28),
              const SizedBox(height: 12),
              const Text(
                'Could not load friends',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: PyreColors.nightText,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: PyreColors.nightMuted),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry loading friends'),
              ),
            ],
          ),
        ),
      );
    }

    if (searching) {
      if (_searchFailed) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: PyreColors.nightMuted, size: 28),
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: const Text(
                    'Search unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: PyreColors.nightText,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: PyreColors.nightMuted),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _retrySearch,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ),
          ),
        );
      }
      if (_hits.isEmpty) {
        return Center(
          child: Semantics(
            liveRegion: true,
            child: Text(
              'No people match “${_searchCtrl.text.trim()}”.',
              style: const TextStyle(
                color: PyreColors.nightMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _hits.length,
        itemBuilder: (context, i) => _PersonRow(
          friend: _hits[i],
          subtitle: '@${_hits[i].username}',
          busy: _busyId == _hits[i].id,
          primaryLabel: 'Add',
          onPrimary: () => _add(_hits[i]),
        ),
      );
    }

    return switch (_pane) {
      _AddFriendsPane.home => _homeBody(),
      _AddFriendsPane.sent => _listPane(
          hint: 'Requests you sent that have not been accepted yet.',
          empty: 'Nothing waiting.',
          people: _bundle.sent,
          subtitle: 'Waiting',
          primaryLabel: 'Requested',
          primaryEnabled: false,
          onPrimary: (_) {},
          onDismiss: (f) => _run(f.id, () => _client.removeFriend(f.id)),
        ),
      _AddFriendsPane.hidden => _listPane(
          hint: 'People you hid from suggestions.',
          empty: 'Nobody hidden.',
          people: _bundle.hidden,
          subtitle: 'Hidden',
          primaryLabel: 'Unhide',
          onPrimary: (f) => _run(f.id, () => _client.restoreFriend(f.id)),
          secondaryLabel: 'Add',
          onSecondary: _add,
        ),
      _AddFriendsPane.ignored => _listPane(
          hint: 'Requests you ignored. Undo to see them in Added Me again.',
          empty: 'Nobody ignored.',
          people: _bundle.deleted,
          subtitle: 'Ignored',
          primaryLabel: 'Undo',
          onPrimary: (f) => _run(f.id, () => _client.restoreFriend(f.id)),
          secondaryLabel: 'Accept',
          secondaryFilled: true,
          onSecondary: _add,
        ),
    };
  }

  Widget _homeBody() {
    final incoming = _showAllIncoming
        ? _bundle.incoming
        : _bundle.incoming.take(_homePreview).toList();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _SectionHeader(title: 'Added Me'),
        if (_bundle.incoming.isEmpty)
          _EmptyLine('No pending requests.')
        else ...[
          for (final f in incoming)
            _PersonRow(
              friend: f,
              subtitle: 'Added you',
              busy: _busyId == f.id,
              primaryLabel: 'Accept',
              primaryFilled: true,
              onPrimary: () => _add(f),
              onDismiss: () => _run(f.id, () => _client.dismissFriend(userId: f.id, kind: 'deleted')),
            ),
          if (_bundle.incoming.length > _homePreview && !_showAllIncoming)
            _MoreButton(
              label: 'View ${_bundle.incoming.length - _homePreview} more',
              onTap: () => setState(() => _showAllIncoming = true),
            ),
        ],
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 26, 16, 8),
          child: Center(
            child: Text(
              'Search by username',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PyreColors.nightMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _listPane({
    required String hint,
    required String empty,
    required List<PyreFriend> people,
    required String subtitle,
    required String primaryLabel,
    required void Function(PyreFriend friend) onPrimary,
    bool primaryEnabled = true,
    bool secondaryFilled = false,
    String? secondaryLabel,
    void Function(PyreFriend friend)? onSecondary,
    void Function(PyreFriend friend)? onDismiss,
  }) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(
            hint,
            style: TextStyle(
              color: PyreColors.nightMuted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
        if (people.isEmpty)
          _EmptyLine(empty)
        else
          for (final f in people)
            _PersonRow(
              friend: f,
              subtitle: subtitle,
              busy: _busyId == f.id,
              primaryLabel: primaryLabel,
              primaryFilled: primaryLabel == 'Accept',
              primaryEnabled: primaryEnabled,
              onPrimary: () => onPrimary(f),
              secondaryLabel: secondaryLabel,
              secondaryFilled: secondaryFilled,
              onSecondary: onSecondary == null ? null : () => onSecondary(f),
              onDismiss: onDismiss == null ? null : () => onDismiss(f),
            ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PyreColors.nightText,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Text(
        text,
        style: TextStyle(
          color: PyreColors.nightMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(
            color: PyreColors.nightText,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.friend,
    required this.subtitle,
    required this.busy,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryFilled = false,
    this.primaryEnabled = true,
    this.secondaryLabel,
    this.secondaryFilled = false,
    this.onSecondary,
    this.onDismiss,
  });

  final PyreFriend friend;
  final String subtitle;
  final bool busy;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final bool primaryFilled;
  final bool primaryEnabled;
  final String? secondaryLabel;
  final bool secondaryFilled;
  final VoidCallback? onSecondary;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final narrow = MediaQuery.sizeOf(context).width < 380;
    final stackActions =
        secondaryLabel != null && onSecondary != null && (narrow || textScale > 1.15);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(
            children: [
              _FriendAvatar(friend: friend),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PyreColors.nightText,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PyreColors.nightMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: subtitle == subtitle.toUpperCase() ? 0.4 : 0,
                      ),
                    ),
                  ],
                ),
              ),
              if (stackActions)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _ActionPill(
                      label: secondaryLabel!,
                      filled: secondaryFilled,
                      busy: busy,
                      onTap: onSecondary!,
                    ),
                    const SizedBox(height: 6),
                    _ActionPill(
                      label: primaryLabel,
                      filled: primaryFilled,
                      busy: busy,
                      enabled: primaryEnabled,
                      onTap: onPrimary,
                    ),
                  ],
                )
              else ...[
                if (secondaryLabel != null && onSecondary != null) ...[
                  _ActionPill(
                    label: secondaryLabel!,
                    filled: secondaryFilled,
                    busy: busy,
                    onTap: onSecondary!,
                  ),
                  const SizedBox(width: 6),
                ],
                _ActionPill(
                  label: primaryLabel,
                  filled: primaryFilled,
                  busy: busy,
                  enabled: primaryEnabled,
                  onTap: onPrimary,
                ),
              ],
              if (onDismiss != null)
                IconButton(
                  onPressed: busy ? null : onDismiss,
                  tooltip: primaryLabel == 'Requested'
                      ? 'Cancel friend request to ${friend.displayName}'
                      : 'Ignore friend request from ${friend.displayName}',
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    foregroundColor: PyreColors.nightText.withValues(alpha: 0.55),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.5,
          color: Colors.white.withValues(alpha: 0.055),
          indent: 72,
        ),
      ],
    );
  }
}

class _FriendAvatar extends StatelessWidget {
  const _FriendAvatar({required this.friend});

  final PyreFriend friend;

  @override
  Widget build(BuildContext context) {
    final initial = friend.displayName.isNotEmpty
        ? friend.displayName[0].toUpperCase()
        : '?';
    final hue = (friend.username.hashCode % 360).toDouble().abs();

    if (friend.avatarUrl != null && friend.avatarUrl!.isNotEmpty) {
      return PyreAvatar(
        user: PyreUser(
          id: friend.id,
          username: friend.username,
          displayName: friend.displayName,
          avatarUrl: friend.avatarUrl,
        ),
        size: 56,
        showRing: true,
      );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: HSLColor.fromAHSL(1, hue, 0.44, 0.46).toColor(),
      child: Text(
        initial,
        style: const TextStyle(
          color: PyreColors.nightText,
          fontSize: 20,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.onTap,
    this.filled = false,
    this.busy = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool busy;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bg = filled
        ? PyreColors.emberHot
        : Colors.white.withValues(alpha: 0.07);
    final fg = filled ? PyreColors.nightText : PyreColors.nightText;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: (busy || !enabled) ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: busy
              ? SizedBox(
                  width: 52,
                  height: 18,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label == 'Add') ...[
                      Text('+ ', style: TextStyle(color: fg, fontWeight: FontWeight.w900)),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: PyreColors.nightText,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: PyreColors.nightMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: PyreColors.nightMuted),
            ],
          ),
        ),
      ),
    );
  }
}
