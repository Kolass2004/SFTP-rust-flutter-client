import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sftp_client/src/rust/api/discovery.dart';

class DiscoveryState {
  final bool isScanning;
  final String? localIp;
  final List<DiscoveredHost> hosts;
  final String? error;

  DiscoveryState({
    this.isScanning = false,
    this.localIp,
    this.hosts = const [],
    this.error,
  });

  DiscoveryState copyWith({
    bool? isScanning,
    String? localIp,
    List<DiscoveredHost>? hosts,
    String? error,
  }) {
    return DiscoveryState(
      isScanning: isScanning ?? this.isScanning,
      localIp: localIp ?? this.localIp,
      hosts: hosts ?? this.hosts,
      error: error ?? this.error,
    );
  }
}

class DiscoveryNotifier extends StateNotifier<DiscoveryState> {
  DiscoveryNotifier() : super(DiscoveryState());

  StreamSubscription<DiscoveredHost>? _subscription;

  /// Detect local IP and automatically start a subnet scan.
  Future<void> startScan() async {
    if (state.isScanning) return;

    final ip = getLocalIp();
    if (ip == null || ip.isEmpty) {
      state = state.copyWith(
        isScanning: false,
        error: 'Unable to detect local IP. Check Wi-Fi connection.',
      );
      return;
    }

    state = state.copyWith(
      isScanning: true,
      localIp: ip,
      hosts: [],
      error: null,
    );

    try {
      final hostStream = scanNetwork(baseIp: ip, timeoutMs: BigInt.from(1500));
      _subscription?.cancel();

      _subscription = hostStream.listen(
        (host) {
          // Avoid duplicate entries
          final current = List<DiscoveredHost>.from(state.hosts);
          if (!current.any((h) => h.ip == host.ip)) {
            current.add(host);
            // Sort by IP numerically
            current.sort((a, b) {
              final aLast = int.tryParse(a.ip.split('.').last) ?? 0;
              final bLast = int.tryParse(b.ip.split('.').last) ?? 0;
              return aLast.compareTo(bLast);
            });
            state = state.copyWith(hosts: current);
          }
        },
        onError: (err) {
          state = state.copyWith(isScanning: false, error: err.toString());
        },
        onDone: () {
          state = state.copyWith(isScanning: false);
        },
      );
    } catch (e) {
      state = state.copyWith(isScanning: false, error: e.toString());
    }
  }

  void stopScan() {
    _subscription?.cancel();
    state = state.copyWith(isScanning: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final discoveryProvider =
    StateNotifierProvider<DiscoveryNotifier, DiscoveryState>((ref) {
  return DiscoveryNotifier();
});
