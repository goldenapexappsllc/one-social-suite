import 'package:flutter/material.dart';
import 'platform_def.dart';

/// 1PrivateSocial platform registry. The order here is the order of the
/// chips on Compose and Preview. The All chip selects the platforms marked
/// inAll (the core set); the others are ticked one at a time.
/// Anything not listed here can use "Share anywhere" on the Preview screen.
/// All use copy+open handoff, which is more reliable than the iOS share
/// sheet for social apps: it copies the shaped caption to the clipboard
/// and opens the target app directly, so the user just pastes and posts.
class PlatformRegistry {
  PlatformRegistry._();

  static const List<PlatformDef> all = <PlatformDef>[
    PlatformDef(
      id: 'whatsapp',
      name: 'WhatsApp',
      shareMode: ShareMode.openAndCopy,
      charLimit: 1024, // photo/video caption limit
      icon: Icons.chat_bubble_outline,
      deepLinkScheme: 'whatsapp://',
      androidPackage: 'com.whatsapp',
    ),
    PlatformDef(
      id: 'instagram',
      name: 'Instagram',
      shareMode: ShareMode.openAndCopy,
      charLimit: 2200,
      icon: Icons.camera_alt_outlined,
      deepLinkScheme: 'instagram://app',
      androidPackage: 'com.instagram.android',
    ),
    PlatformDef(
      id: 'facebook',
      name: 'Facebook',
      shareMode: ShareMode.openAndCopy,
      charLimit: 63206,
      icon: Icons.facebook,
      deepLinkScheme: 'fb://',
      androidPackage: 'com.facebook.katana',
    ),
    PlatformDef(
      id: 'tiktok',
      name: 'TikTok',
      shareMode: ShareMode.openAndCopy,
      charLimit: 4000, // TikTok's own page says 4,000 (Aug 2026)
      icon: Icons.music_note,
      deepLinkScheme: 'tiktok://',
      androidPackage: 'com.zhiliaoapp.musically',
    ),
    PlatformDef(
      id: 'youtube',
      name: 'YouTube',
      shareMode: ShareMode.openAndCopy,
      charLimit: 5000,
      icon: Icons.smart_display_outlined,
      deepLinkScheme: 'youtube://',
      androidPackage: 'com.google.android.youtube',
      inAll: false,
    ),
    PlatformDef(
      id: 'x',
      name: 'X',
      shareMode: ShareMode.openAndCopy,
      charLimit: 280,
      glyph: 'X',
      deepLinkScheme: 'twitter://',
      androidPackage: 'com.twitter.android',
    ),
    PlatformDef(
      id: 'snapchat',
      name: 'Snapchat',
      shareMode: ShareMode.openAndCopy,
      charLimit: 250,
      glyph: 'SC',
      deepLinkScheme: 'snapchat://',
      androidPackage: 'com.snapchat.android',
    ),
    PlatformDef(
      id: 'threads',
      name: 'Threads',
      shareMode: ShareMode.openAndCopy,
      charLimit: 500,
      glyph: '@',
      deepLinkScheme: 'barcelona://',
      androidPackage: 'com.instagram.barcelona',
    ),
    PlatformDef(
      id: 'pinterest',
      name: 'Pinterest',
      shareMode: ShareMode.openAndCopy,
      charLimit: 500,
      icon: Icons.push_pin_outlined,
      deepLinkScheme: 'pinterest://',
      androidPackage: 'com.pinterest',
    ),
    PlatformDef(
      id: 'linkedin',
      name: 'LinkedIn',
      shareMode: ShareMode.openAndCopy,
      charLimit: 3000,
      glyph: 'in',
      deepLinkScheme: 'linkedin://',
      androidPackage: 'com.linkedin.android',
    ),
    PlatformDef(
      id: 'telegram',
      name: 'Telegram',
      shareMode: ShareMode.openAndCopy,
      charLimit: 1024, // free accounts; Premium allows 4096
      icon: Icons.send_outlined,
      deepLinkScheme: 'tg://',
      androidPackage: 'org.telegram.messenger',
      inAll: false,
    ),
    PlatformDef(
      id: 'nextdoor',
      name: 'Nextdoor',
      shareMode: ShareMode.openAndCopy,
      charLimit: 1000,
      glyph: 'n',
      deepLinkScheme: 'nextdoor://',
      androidPackage: 'com.nextdoor',
    ),
  ];

  /// Platforms the All chip selects.
  static List<PlatformDef> get core =>
      all.where((PlatformDef p) => p.inAll).toList();

  static int get count => all.length;

  static PlatformDef? byId(String id) {
    for (final PlatformDef p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
