import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sftp_client/src/theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;

  const OnboardingScreen({super.key, required this.onPermissionsGranted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _storageGranted = false;
  bool _locationGranted = false; // Required for Wi-Fi SSID / local network scan on some platforms

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final storage = await Permission.storage.status;
    final manageStorage = await Permission.manageExternalStorage.status;
    final location = await Permission.locationWhenInUse.status;

    setState(() {
      _storageGranted = storage.isGranted || manageStorage.isGranted;
      _locationGranted = location.isGranted;
    });

    if (_storageGranted && _locationGranted) {
      widget.onPermissionsGranted();
    }
  }

  Future<void> _requestStorage() async {
    var status = await Permission.storage.request();
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    setState(() {
      _storageGranted = status.isGranted;
    });
    _checkAllAndProceed();
  }

  Future<void> _requestLocation() async {
    final status = await Permission.locationWhenInUse.request();
    setState(() {
      _locationGranted = status.isGranted;
    });
    _checkAllAndProceed();
  }

  void _checkAllAndProceed() {
    if (_storageGranted) {
      widget.onPermissionsGranted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryViolet.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.folder_special_rounded,
                  size: 48,
                  color: AppTheme.primaryLight,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome to\nSFTP Local Manager',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'High-performance, secure local network file transfer between your device and SSH/SFTP servers.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Required Permissions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textMuted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildPermissionTile(
                icon: Icons.sd_card_rounded,
                title: 'Storage & File Access',
                subtitle: 'Needed to read and save files on your device local storage',
                isGranted: _storageGranted,
                onRequest: _requestStorage,
              ),
              const SizedBox(height: 12),
              _buildPermissionTile(
                icon: Icons.wifi_find_rounded,
                title: 'Local Network Discovery',
                subtitle: 'Allows scanning your Wi-Fi subnet for available SFTP servers',
                isGranted: _locationGranted,
                onRequest: _requestLocation,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _storageGranted ? widget.onPermissionsGranted : _requestStorage,
                  child: Text(
                    _storageGranted ? 'Get Started' : 'Grant Permissions',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGranted ? AppTheme.successGreen.withOpacity(0.4) : AppTheme.cardDark,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isGranted
                  ? AppTheme.successGreen.withOpacity(0.15)
                  : AppTheme.cardDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isGranted ? AppTheme.successGreen : AppTheme.textSecondary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isGranted ? null : onRequest,
            icon: Icon(
              isGranted ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
              color: isGranted ? AppTheme.successGreen : AppTheme.primaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
