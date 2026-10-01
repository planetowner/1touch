import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:onetouch/session_screen.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/session/session_data_synchronizer.dart';

class SessionSyncLifecycle extends StatefulWidget {
  const SessionSyncLifecycle({super.key, required this.child});

  final Widget child;

  @override
  State<SessionSyncLifecycle> createState() => _SessionSyncLifecycleState();
}

class _SessionSyncLifecycleState extends State<SessionSyncLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !authSession.isAuthenticated ||
        !isAppSessionReady) {
      return;
    }
    unawaited(_synchronize());
  }

  Future<void> _synchronize() async {
    try {
      await sessionDataSynchronizer.synchronize(
        trigger: CacheSyncTrigger.foreground,
      );
    } on Object {
      // Existing local data remains visible while foreground sync is offline.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
