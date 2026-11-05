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
Type it in the compose box. Add a video if you like (see HOW VIDEO WORKS below).

3. Translate and tailor it with AI Assist.
Pick a target language and AI Assist adapts your text naturally, so you can write in one language and post in another. Choose your platforms, or tap All, and each one gets a version shaped to its style, tone, and character limit. Every plan includes a 2-week free trial.

AI Assist is the only feature that sends anything off your device. Your text passes through our proxy to OpenAI to be rewritten -- our proxy doesn't store it, and OpenAI doesn't use it to train their models. It's held briefly for abuse prevention, then deleted. Your videos are never sent anywhere by $kAppName.

4. Review and copy.
Tap Next. Swipe or use the arrows to step through the versions. Tap Copy on any card to copy that one, or edit it by hand first.

5. Share it.
Tap Open on a card to copy that caption and jump straight to the app. Tap Share All to move through your selected apps one at a time. Or tap Share anywhere to use your phone's own share menu and send to WhatsApp, Telegram, Messages, email, Notes, Slack, or anything else.

HOW VIDEO WORKS

1. Record or choose a video.
On the Compose screen, tap Record video. Pick a length from 15 seconds up to 3 minutes, then tap the red button. It stops by itself at the length you picked. Or tap Photo / video to use one you already have.

2. Check the notes on the record screen.
It shows about how big the file will be, and warns you if an app you picked will trim the video or is likely to reject the file size.

3. Name it, write your message, and pick your apps.
Every video gets a name with the date and time. You can change it. The video stays attached to your post.

4. Tap Next, then tap Open on an app.
$kAppName saves the video to your Photos, copies the caption for that app, and opens the app. The first time, your phone asks if $kAppName may add videos to Photos. It can only add. It cannot read your library.

5. In that app, start a new post.
Pick the video from Photos and paste the caption. Then post.

Tip: Share anywhere sends the video and caption together to apps that take both, like WhatsApp, Telegram and Messages. Some apps keep only the video.

Your videos are kept on your phone.
Open the Drafts tab and look under Videos. Tap a video to start a new post with it. Tap the three dots to rename it or delete it.

Deleted videos go to Trash.
Tap the trash icon at the top of Drafts. Videos stay there for 7 days, then are removed for good. You can restore one any time before that. Right after you delete a video, an Undo bar appears for a few seconds. Tap the storage icon to see how much space your videos use, and to turn the 7-day clean-up off.

QUESTIONS

Can I write in my own language and post in another?
Yes. Write or paste in almost any language, pick the output language, and AI Assist handles the translation.

How do I post photos or videos?
For a video, record or choose it in $kAppName and tap Open (see HOW VIDEO WORKS). For a photo, add it inside the app you are posting to, using its own photo tools. $kAppName handles the words.

I don't see my app in the list. What do I do?
Pick any app, then tap Share anywhere on the Preview screen. It opens your phone's share menu, where you can choose any app that takes text, photos or videos.

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
