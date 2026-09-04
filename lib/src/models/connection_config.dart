import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ConnectionConfig {
  final String id;
  final String label;
  final String host;
  final int port;
  final String username;
  final String password;
  final DateTime lastConnected;

  ConnectionConfig({
    required this.id,
    required this.label,
    required this.host,
    this.port = 22,
    required this.username,
    required this.password,
    DateTime? lastConnected,
  }) : lastConnected = lastConnected ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'lastConnected': lastConnected.toIso8601String(),
      };

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      id: json['id'] as String,
      label: json['label'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      password: json['password'] as String,
      lastConnected: json['lastConnected'] != null
          ? DateTime.parse(json['lastConnected'] as String)
          : DateTime.now(),
    );
  }
}

class CredentialStorage {
  static const _storage = FlutterSecureStorage();
  static const _savedConnectionsKey = 'sftp_saved_connections';

  /// Save or update a connection profile securely.
  static Future<void> saveConnection(ConnectionConfig config) async {
    final connections = await getSavedConnections();
    final index = connections.indexWhere((c) => c.id == config.id || (c.host == config.host && c.username == config.username));
    if (index >= 0) {
      connections[index] = config;
    } else {
      connections.add(config);
    }
    final raw = jsonEncode(connections.map((c) => c.toJson()).toList());
    await _storage.write(key: _savedConnectionsKey, value: raw);
  }

  /// Retrieve all saved connections.
  static Future<List<ConnectionConfig>> getSavedConnections() async {
    final raw = await _storage.read(key: _savedConnectionsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => ConnectionConfig.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Remove a saved connection.
  static Future<void> deleteConnection(String id) async {
    final connections = await getSavedConnections();
    connections.removeWhere((c) => c.id == id);
    final raw = jsonEncode(connections.map((c) => c.toJson()).toList());
    await _storage.write(key: _savedConnectionsKey, value: raw);
  }
}
