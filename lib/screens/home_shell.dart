import 'package:flutter/material.dart';
import 'compose_screen.dart';
import 'connections_screen.dart';
import 'drafts_screen.dart';
import 'history_screen.dart';
import 'privacy_screen.dart';
import '../services/storage_service.dart';
import '../widgets/lock_gate.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

/// Tab positions, so the indexes aren't scattered as magic numbers.
const int _kCompose = 0;
const int _kAppInfo = 1;
const int _kDrafts = 2;
const int _kHistory = 3;

class _HomeShellState extends State<HomeShell> {
  late int _index;
  int _draftsRefreshKey  = 0;
  int _historyRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    // First launch lands on App Info so a new user reads how the app works
    // before writing anything. Every launch after that opens on Compose.
    final bool seen = StorageService.instance.hasSeenAppInfo;
    _index = seen ? _kCompose : _kAppInfo;
    if (!seen) {
      StorageService.instance.markAppInfoSeen();
    }
  }

  void _onTap(int i) => setState(() {
        if (i == _kDrafts) _draftsRefreshKey++;
        if (i == _kHistory) _historyRefreshKey++;
        _index = i;
      });

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = <Widget>[
      const ComposeScreen(),
      const ConnectionsScreen(),
      DraftsScreen(key: ValueKey<int>(_draftsRefreshKey)),
      HistoryScreen(key: ValueKey<int>(_historyRefreshKey)),
      const PrivacyScreen(),
    ];

    return LockGate(
      child: Scaffold(
        body: IndexedStack(index: _index, children: screens),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _index,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.edit_note),
              label: 'Compose',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.hub_outlined),
              label: 'App Info',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.drafts_outlined),
              label: 'Drafts',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.security),
              label: 'Security',
            ),
          ],
        ),
      ),
    );
  }
}
