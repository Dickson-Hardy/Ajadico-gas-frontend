/// Implemented by data-entry screens that must veto system-back / logout
/// navigation while the user still has unsaved input on a shared tablet.
mixin UnsavedWorkAware {
  bool get hasUnsavedWork;
}

/// Tracks the screen currently responsible for guarding unsaved work.
/// Screens register in initState and unregister in dispose (identity-safe,
/// so a mounting successor is never cleared by the predecessor's dispose).
class ShellBackGuard {
  ShellBackGuard._();

  static UnsavedWorkAware? _active;

  static void register(UnsavedWorkAware owner) {
    _active = owner;
  }

  static void unregister(UnsavedWorkAware owner) {
    if (identical(_active, owner)) {
      _active = null;
    }
  }

  static bool get hasUnsavedWork => _active?.hasUnsavedWork ?? false;
}
