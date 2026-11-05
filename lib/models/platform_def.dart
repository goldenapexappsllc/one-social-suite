import 'package:flutter/widgets.dart';

/// How a platform receives a shared post.
enum ShareMode {
  shareSheet,   // native share sheet + deep-link handoff
  openAndCopy,  // no public share API: open app + copy caption to clipboard
}

/// Static definition of a social platform in the gateway.
@immutable
class PlatformDef {
  const PlatformDef({
    required this.id,
    required this.name,
    required this.shareMode,
    required this.charLimit,
    this.icon,
    this.glyph,
    this.deepLinkScheme,
    this.androidPackage,
    this.inAll = true,
  });

  final String id;
  final String name;
  final ShareMode shareMode;
  final int charLimit;
  final IconData? icon;
  final String? glyph;

  /// Used on iOS via canLaunchUrl/launchUrl. iOS's scheme check is coarse
  /// (per-scheme, ignores host/path), so this works reliably there.
  final String? deepLinkScheme;

  /// Used on Android via MainActivity's app_launcher method channel, which
  /// opens the app directly by its package name. More reliable than
  /// deepLinkScheme on Android, since many apps only register narrow,
  /// path-specific intent filters rather than a generic "open app" scheme.
  final String? androidPackage;

  /// Whether the "All" chip on Compose includes this platform. Each platform
  /// in a post uses one AI Assist, so extra platforms stay out of "All" and
  /// are ticked one at a time.
  final bool inAll;

  bool get isOpenAndCopy => shareMode == ShareMode.openAndCopy;
}
