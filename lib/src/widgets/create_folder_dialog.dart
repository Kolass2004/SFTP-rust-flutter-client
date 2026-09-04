import 'package:flutter/material.dart';

Future<String?> showCreateFolderDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Create New Folder'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Folder Name',
          hintText: 'New Folder',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(context).pop(text);
            }
          },
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

Future<String?> showRenameDialog(BuildContext context, String currentName) {
  final controller = TextEditingController(text: currentName);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'New Name',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isNotEmpty && text != currentName) {
              Navigator.of(context).pop(text);
            }
          },
          child: const Text('Rename'),
        ),
      ],
    ),
  );
}
