import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sftp_client/src/models/connection_config.dart';
import 'package:sftp_client/src/providers/sftp_provider.dart';
import 'package:sftp_client/src/theme/app_theme.dart';

class ConnectionDialog extends ConsumerStatefulWidget {
  final String? initialHost;
  final VoidCallback onConnected;

  const ConnectionDialog({super.key, this.initialHost, required this.onConnected});

  @override
  ConsumerState<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends ConsumerState<ConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  final _portController = TextEditingController(text: '22');
  final _userController = TextEditingController(text: 'root');
  final _passController = TextEditingController();
  final _labelController = TextEditingController();
  bool _saveCredential = true;
  bool _isConnecting = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.initialHost ?? '');
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isConnecting = true;
      _errorMsg = null;
    });

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 22;
    final username = _userController.text.trim();
    final password = _passController.text;
    final label = _labelController.text.trim();

    final res = await ref.read(sftpProvider.notifier).connect(
          host: host,
          port: port,
          username: username,
          password: password,
        );

    if (mounted) {
      setState(() => _isConnecting = false);
      if (res.success) {
        if (_saveCredential) {
          final config = ConnectionConfig(
            id: '${host}_$username',
            label: label.isNotEmpty ? label : '$username@$host',
            host: host,
            port: port,
            username: username,
            password: password,
          );
          await CredentialStorage.saveConnection(config);
        }
        if (mounted && context.mounted) {
          Navigator.of(context).pop();
        }
        widget.onConnected();
      } else {
        setState(() => _errorMsg = res.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryViolet.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.key_rounded, color: AppTheme.primaryLight, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Connect to SFTP', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.errorRed.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host / IP Address',
                  hintText: '192.168.1.100',
                  prefixIcon: Icon(Icons.dns_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter IP address or hostname' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _userController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'root',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '22',
                        prefixIcon: Icon(Icons.numbers_rounded),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: '••••••••',
                  prefixIcon: Icon(Icons.lock_rounded),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Enter SSH password' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Label (Optional)',
                  hintText: 'Home Server',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Save credentials securely', style: TextStyle(fontSize: 14)),
                value: _saveCredential,
                activeColor: AppTheme.primaryViolet,
                onChanged: (v) => setState(() => _saveCredential = v ?? true),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isConnecting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isConnecting ? null : _submit,
          child: _isConnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Connect'),
        ),
      ],
    );
  }
}
