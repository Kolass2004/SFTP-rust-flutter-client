import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sftp_client/src/models/connection_config.dart';
import 'package:sftp_client/src/providers/discovery_provider.dart';
import 'package:sftp_client/src/providers/sftp_provider.dart';
import 'package:sftp_client/src/theme/app_theme.dart';
import 'package:sftp_client/src/widgets/connection_dialog.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  final VoidCallback onConnected;

  const DiscoveryScreen({super.key, required this.onConnected});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  List<ConnectionConfig> _savedConnections = [];

  @override
  void initState() {
    super.initState();
    _loadSavedConnections();
    // Auto start subnet scan
    Future.microtask(() {
      ref.read(discoveryProvider.notifier).startScan();
    });
  }

  Future<void> _loadSavedConnections() async {
    final list = await CredentialStorage.getSavedConnections();
    if (mounted) {
      setState(() => _savedConnections = list);
    }
  }

  void _showConnectDialog({String? initialHost}) {
    showDialog(
      context: context,
      builder: (context) => ConnectionDialog(
        initialHost: initialHost,
        onConnected: () {
          _loadSavedConnections();
          widget.onConnected();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discoveryState = ref.watch(discoveryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryViolet.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lan_rounded, color: AppTheme.primaryLight, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Local Network Scanner'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              discoveryState.isScanning ? Icons.stop_rounded : Icons.refresh_rounded,
              color: AppTheme.primaryLight,
            ),
            tooltip: discoveryState.isScanning ? 'Stop Scan' : 'Rescan Network',
            onPressed: () {
              if (discoveryState.isScanning) {
                ref.read(discoveryProvider.notifier).stopScan();
              } else {
                ref.read(discoveryProvider.notifier).startScan();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Banner Status
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardDark),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: discoveryState.isScanning
                          ? const CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.primaryLight,
                            )
                          : const Icon(Icons.wifi_rounded, color: AppTheme.successGreen),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            discoveryState.isScanning
                                ? 'Scanning LAN Subnet (${discoveryState.localIp ?? "Detecting..."})'
                                : 'Local Subnet: ${discoveryState.localIp ?? "Not Connected"}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            discoveryState.isScanning
                                ? 'Searching for open port 22 (SSH/SFTP)...'
                                : '${discoveryState.hosts.length} server(s) found on network',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Discovered Host List Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Discovered Servers',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showConnectDialog(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Manual IP'),
                  ),
                ],
              ),
            ),
          ),

          // Discovered Host Items
          if (discoveryState.hosts.isEmpty && !discoveryState.isScanning)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted.withOpacity(0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'No SSH servers auto-detected on this subnet',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _showConnectDialog(),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Connect Manually'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final host = discoveryState.hosts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardDark),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.computer_rounded, color: AppTheme.accentCyan, size: 22),
                          ),
                          title: Text(
                            host.hostname.isNotEmpty ? host.hostname : host.ip,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'IP: ${host.ip} • Port 22 • Ping: ${host.responseMs.toInt()}ms',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () => _showConnectDialog(initialHost: host.ip),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            child: const Text('Connect'),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: discoveryState.hosts.length,
                ),
              ),
            ),

          // Saved Connections Section
          if (_savedConnections.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Saved Connections',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final config = _savedConnections[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceDark,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.cardDark),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryViolet.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bookmark_rounded, color: AppTheme.primaryLight, size: 22),
                          ),
                          title: Text(
                            config.label.isNotEmpty ? config.label : config.host,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${config.username}@${config.host}:${config.port}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                                onPressed: () async {
                                  await CredentialStorage.deleteConnection(config.id);
                                  _loadSavedConnections();
                                },
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final res = await ref.read(sftpProvider.notifier).connect(
                                        host: config.host,
                                        port: config.port,
                                        username: config.username,
                                        password: config.password,
                                      );
                                  if (res.success) {
                                    widget.onConnected();
                                  } else {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(res.message), backgroundColor: AppTheme.errorRed),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text('Connect'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _savedConnections.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}
