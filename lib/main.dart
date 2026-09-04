import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sftp_client/src/providers/sftp_provider.dart';
import 'package:sftp_client/src/rust/frb_generated.dart';
import 'package:sftp_client/src/screens/discovery_screen.dart';
import 'package:sftp_client/src/screens/file_browser_screen.dart';
import 'package:sftp_client/src/screens/onboarding_screen.dart';
import 'package:sftp_client/src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  runApp(const ProviderScope(child: SftpApp()));
}

class SftpApp extends ConsumerStatefulWidget {
  const SftpApp({super.key});

  @override
  ConsumerState<SftpApp> createState() => _SftpAppState();
}

class _SftpAppState extends ConsumerState<SftpApp> {
  bool _hasPermission = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final storage = await Permission.storage.isGranted;
    final manageStorage = await Permission.manageExternalStorage.isGranted;
    setState(() {
      _hasPermission = storage || manageStorage;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sftpState = ref.watch(sftpProvider);

    return MaterialApp(
      title: 'SFTP File Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: _isChecking
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryLight),
              ),
            )
          : !_hasPermission
              ? OnboardingScreen(
                  onPermissionsGranted: () {
                    setState(() => _hasPermission = true);
                  },
                )
              : sftpState.status == ConnectionStatus.connected
                  ? FileBrowserScreen(
                      onDisconnect: () {
                        // Return to discovery screen
                      },
                    )
                  : DiscoveryScreen(
                      onConnected: () {
                        // Navigation handled by sftpState listener above
                      },
                    ),
    );
  }
}
