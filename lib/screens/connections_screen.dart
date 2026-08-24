import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_name.dart';
import '../theme/app_theme.dart';

/// Plain-language how-to shown on the App Info tab. Built as a function so
/// the app name resolves per platform, and returned as one string so it can
/// be copied to the clipboard and pasted into a translator.
String howToUse() => """How $kAppName works

Draft once, adapt it for any audience, and share it to any app on your phone in seconds. No account, no sign-up.

BEFORE YOU START

Sign in to your social apps first.
$kAppName never asks for your passwords and never stores them. Open Instagram, X, TikTok, or whichever apps you use and make sure you are already signed in on this phone.

STEP BY STEP

1. No account needed here.
There is no sign-in or setup in $kAppName. Open it and start writing.

2. Write your message once.
Type it in the compose box.

3. Translate and tailor it with AI Assist.
Pick a target language and AI Assist adapts your text naturally, so you can write in one language and post in another. Choose your platforms, or tap All, and each one gets a version shaped to its style, tone, and character limit. Every plan includes a 2-week free trial.

AI Assist is the one feature that sends anything off your device: your text goes to OpenAI to be rewritten, and it is not stored anywhere.

4. Review and copy.
Swipe or use the arrows to step through the versions. Tap the copy icon on any card to copy that one, or edit it by hand first.

5. Share it.
Tap Share All to move through your selected apps one at a time. Or tap Share anywhere to use your phone's own share menu and send to WhatsApp, Telegram, Messages, email, Notes, Slack, or anything else that takes text. Paste your caption, attach any photo or video inside that app, and post.

QUESTIONS

Can I write in my own language and post in another?
Yes. Write or paste in any language, pick the output language, and AI Assist handles the translation.

How do I post photos or videos?
Add them inside the app you are posting to, using its own photo and video tools. $kAppName handles the words.

Why doesn't $kAppName post for me automatically?
Because that would mean handing us your passwords and storing them on a server. We won't ask for them. You stay signed in where you already are, and nothing about your accounts ever touches our servers. Not running that machinery is also why $kAppName costs a few dollars a month instead of fifteen or more.""";

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {

  Future<void> _copyGuide() async {
    await Clipboard.setData(ClipboardData(text: howToUse()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Instructions copied -- paste them anywhere, '
            'including a translator.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Widget _guideCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text('How $kAppName works',
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              TextButton.icon(
                onPressed: _copyGuide,
                icon: const Icon(Icons.copy, size: 16, color: AppColors.gold),
                label: const Text('Copy',
                    style: TextStyle(color: AppColors.gold, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Copy these steps and paste them into a translator to read them '
            'in your own language.',
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 12.5, height: 1.35),
          ),
          const SizedBox(height: 14),
          SelectableText(
            howToUse(),
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return Container(
      color: AppColors.black,
      child: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 12),
                  // New vertical logo -- replaces text title + old BrandLogo
                  Image.asset(
                    Platform.isIOS
                        ? 'assets/images/logo_header_ios.png'
                        : 'assets/images/logo_header_android.png',
                    width: screenWidth * 0.82,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  _guideCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
