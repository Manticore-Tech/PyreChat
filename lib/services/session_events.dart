typedef SessionInvalidatedHandler = void Function(String message);

/// Process-local signal for authenticated client calls that prove the saved
/// session is no longer usable.
///
/// The signed-in shell owns the navigation response. Keeping that response out
/// of PyreClient means networking code never reaches into Flutter navigation.
class SessionEvents {
  SessionEvents._();

  static final SessionEvents instance = SessionEvents._();

  final List<SessionInvalidatedHandler> _handlers = [];

  void addInvalidatedListener(SessionInvalidatedHandler handler) {
    if (!_handlers.contains(handler)) _handlers.add(handler);
  }

  void removeInvalidatedListener(SessionInvalidatedHandler handler) {
    _handlers.remove(handler);
  }

  void invalidate([String message = 'Your session expired. Sign in again.']) {
    for (final handler in List<SessionInvalidatedHandler>.from(_handlers)) {
      handler(message);
    }
  }
}
