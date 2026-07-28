import 'package:flutter/material.dart';
import 'platform_def.dart';

/// 1Social platform registry -- 9 platforms, all using copy+open handoff.
/// Copy+open is more reliable than the iOS share sheet for social apps:
/// it copies the shaped caption to clipboard and opens the target app
/// directly, so the user just pastes and posts. No share-sheet roulette.
class PlatformRegistry {
  PlatformRegistry._();

  static const List<PlatformDef> all = <PlatformDef>[
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
      id: 'x',
      name: 'X',
      shareMode: ShareMode.openAndCopy,
      charLimit: 280,
      glyph: 'X',
      deepLinkScheme: 'twitter://',
      androidPackage: 'com.twitter.android',
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
      id: 'nextdoor',
      name: 'Nextdoor',
      shareMode: ShareMode.openAndCopy,
      charLimit: 1000,
      glyph: 'n',
      deepLinkScheme: 'nextdoor://',
      androidPackage: 'com.nextdoor',
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
      id: 'tiktok',
      name: 'TikTok',
      shareMode: ShareMode.openAndCopy,
      charLimit: 2200,
      icon: Icons.music_note,
      deepLinkScheme: 'tiktok://',
      androidPackage: 'com.zhiliaoapp.musically',
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
      id: 'facebook',
      name: 'Facebook',
      shareMode: ShareMode.openAndCopy,
      charLimit: 63206,
      icon: Icons.facebook,
      deepLinkScheme: 'fb://',
      androidPackage: 'com.facebook.katana',
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
  ];

  static int get count => all.length;

  static PlatformDef? byId(String id) {
    for (final PlatformDef p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
