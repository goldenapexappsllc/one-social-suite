import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/platform_def.dart';

enum ShareOutcome {
  sharedViaSheet,
  copiedAndOpened,
  appNotFound,
  failed,
}

class ShareService {
  const ShareService();

  static const MethodChannel _appLauncherChannel =
      MethodChannel('com.goldenapexapps.onesocial/app_launcher');

  Future<ShareOutcome> shareToPlatform({
    required PlatformDef platform,
    required String caption,
    String? mediaPath,
  }) async {
    try {
      if (platform.isOpenAndCopy) {
        return await _openAndCopy(platform, caption);
      }
      return await _shareSheet(caption, mediaPath);
    } catch (_) {
      return ShareOutcome.failed;
    }
  }

  Future<ShareOutcome> _shareSheet(String caption, String? mediaPath) async {
    final ShareParams params = (mediaPath != null && mediaPath.isNotEmpty)
        ? ShareParams(text: caption, files: <XFile>[XFile(mediaPath)])
        : ShareParams(text: caption);
    await SharePlus.instance.share(params);
    return ShareOutcome.sharedViaSheet;
  }

  Future<ShareOutcome> _openAndCopy(
      PlatformDef platform, String caption) async {
    await Clipboard.setData(ClipboardData(text: caption));

    if (Platform.isAndroid && platform.androidPackage != null) {
      return _openAndCopyAndroid(platform);
    }
    return _openAndCopyIOS(platform);
  }

  /// Android path: open the app directly by its package name via the
  /// native method channel, rather than relying on a custom URL scheme.
  /// Many apps (Facebook and Instagram included) only register narrow,
  /// path-specific intent filters on Android, not a generic "open app"
  /// scheme, which is why canLaunchUrl alone isn't reliable here.
  Future<ShareOutcome> _openAndCopyAndroid(PlatformDef platform) async {
    try {
      final bool opened = await _appLauncherChannel.invokeMethod<bool>(
            'openApp',
            <String, String>{'packageName': platform.androidPackage!},
          ) ??
          false;
      return opened ? ShareOutcome.copiedAndOpened : ShareOutcome.appNotFound;
    } on PlatformException {
      return ShareOutcome.appNotFound;
    }
  }

  /// iOS path: canLaunchUrl/launchUrl against the platform's custom URL
  /// scheme.
  Future<ShareOutcome> _openAndCopyIOS(PlatformDef platform) async {
    final String? scheme = platform.deepLinkScheme;
    if (scheme != null) {
      final Uri uri = Uri.parse(scheme);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return ShareOutcome.copiedAndOpened;
      }
    }
    return ShareOutcome.appNotFound;
  }

  /// Opens the plain share sheet with the caption (and media), not tied
  /// to any one platform. Lets the user send anywhere on their device.
  Future<ShareOutcome> shareAnywhere({
    required String caption,
    String? mediaPath,
  }) async {
    try {
      final ShareParams params = (mediaPath != null && mediaPath.isNotEmpty)
          ? ShareParams(text: caption, files: <XFile>[XFile(mediaPath)])
          : ShareParams(text: caption);
      await SharePlus.instance.share(params);
      return ShareOutcome.sharedViaSheet;
    } catch (_) {
      return ShareOutcome.failed;
    }
  }
}
