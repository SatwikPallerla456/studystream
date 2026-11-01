import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/catalog/media_catalog_repository.dart';
import '../../shared/widgets/media_categories.dart';
import '../../shared/widgets/study_ui.dart';
import '../../shared/widgets/tangerine_controls.dart';

Future<({String name, LibraryKind kind})?> showLibrarySetup(
  BuildContext context,
  String suggested, {
  LibraryKind initialKind = LibraryKind.movies,
}) => showStudyAdaptiveModal<({String name, LibraryKind kind})>(
  context: context,
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
  Widget build(BuildContext context) => StudyModalFrame(
    title: 'Add a library',
    description:
        'Name your library, choose its content, then connect a source folder.',
    icon: mediaCategoryIcon(_kind),
    maxWidth: 640,
    primaryAction: TangerineInteraction(
      enabled: _name.text.trim().isNotEmpty,
      child: FilledButton.icon(
        onPressed: _name.text.trim().isEmpty
            ? null
            : () => Navigator.pop(context, (
                name: _name.text.trim(),
                kind: _kind,
              )),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Choose source folder'),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.only(top: AppSpace.xs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _name,
            maxLength: 200,
            decoration: const InputDecoration(labelText: 'Library name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.md),
          TangerineChoicePicker<LibraryKind>(
            value: _kind,
            label: 'Content',
            icon: mediaCategoryIcon(_kind),
            choices: [
              for (final kind in [
                ...LibraryKind.values.where(
                  (kind) => kind != LibraryKind.mixed,
                ),
                LibraryKind.mixed,
              ])
                TangerineChoice(
                  value: kind,
                  label: kind.label,
                  icon: mediaCategoryIcon(kind),
                ),
            ],
            onChanged: (value) => setState(() {
              if (_name.text == _kind.label) _name.text = value.label;
              _kind = value;
            }),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'Your files stay in their folder. Tangerine scans and organises them into this named library.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}
