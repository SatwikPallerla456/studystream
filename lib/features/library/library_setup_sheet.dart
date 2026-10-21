import 'package:flutter/material.dart';
import '../../domain/catalog/media_catalog_repository.dart';

Future<({String name, LibraryKind kind})?> showLibrarySetup(
  BuildContext context,
  String suggested, {
  LibraryKind initialKind = LibraryKind.movies,
}) => showModalBottomSheet<({String name, LibraryKind kind})>(
  context: context,
  isScrollControlled: true,
  builder: (context) => _LibrarySetup(suggested, initialKind),
);

class _LibrarySetup extends StatefulWidget {
  const _LibrarySetup(this.suggested, this.initialKind);
  final String suggested;
  final LibraryKind initialKind;
  @override
  State<_LibrarySetup> createState() => _LibrarySetupState();
}

class _LibrarySetupState extends State<_LibrarySetup> {
  late final _name = TextEditingController(text: widget.suggested);
  late LibraryKind _kind = widget.initialKind;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'What would you like to add?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextField(
            controller: _name,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Library name'),
            onChanged: (_) => setState(() {}),
          ),
          DropdownButtonFormField<LibraryKind>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'Library content'),
            items: [
              for (final kind in LibraryKind.values)
                DropdownMenuItem(value: kind, child: Text(kind.label)),
            ],
            onChanged: (value) => setState(() {
              if (_name.text == _kind.label) _name.text = value!.label;
              _kind = value!;
            }),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _name.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, (
                    name: _name.text.trim(),
                    kind: _kind,
                  )),
            child: const Text('Choose source folder'),
          ),
        ],
      ),
    ),
  );
}
