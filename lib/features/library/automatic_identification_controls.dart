import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/app_providers.dart';
import '../../domain/catalog/automatic_catalog_identification.dart';

/// One setting controls scan-triggered and explicitly queued identification.
class AutomaticIdentificationControls extends ConsumerStatefulWidget {
  const AutomaticIdentificationControls({
    super.key,
    required this.libraryId,
    this.onQueued,
  });
  final String libraryId;
  final VoidCallback? onQueued;
  @override
  ConsumerState<AutomaticIdentificationControls> createState() =>
      _AutomaticControlsState();
}

class _AutomaticControlsState
    extends ConsumerState<AutomaticIdentificationControls> {
  bool _busy = false;
  String? _message;
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted)
        setState(
          () => _message = 'Could not update identification. Try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(appDatabaseProvider),
        service = ref.watch(libraryProcessingProvider);
    return StreamBuilder(
      stream: db
          .customSelect(
            'SELECT value FROM app_settings WHERE key=?',
            variables: [
              drift.Variable(
                AutomaticCatalogIdentification.setting(widget.libraryId),
              ),
            ],
            readsFrom: {db.appSettings},
          )
          .watch(),
      builder: (context, snapshot) {
        final enabled = snapshot.data?.firstOrNull?.data['value'] != 'false';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Automatically identify movies & TV'),
                  subtitle: const Text(
                    'Fetch TheTVDB descriptions and artwork for confident matches. Uncertain titles need review; manual matches and cleared matches are kept.',
                  ),
                  value: enabled,
                  onChanged: _busy
                      ? null
                      : (value) => _run(
                          () => service.setAutomaticIdentification(
                            widget.libraryId,
                            value,
                          ),
                        ),
                ),
                const Text(
                  'Runs while Tangerine is open. Sends title, year and episode information to TheTVDB; files, paths, notes and progress stay private.',
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('Identify unmatched titles'),
                  onPressed: _busy || !enabled
                      ? null
                      : () => _run(() async {
                          await service.store.enqueueLibrary(
                            widget.libraryId,
                            force: true,
                            only: 'identify',
                          );
                          if (mounted)
                            setState(
                              () => _message =
                                  'Unmatched movie and TV files queued. Check Library processing for results or titles needing review.',
                            );
                          widget.onQueued?.call();
                        }),
                ),
                if (_busy) const LinearProgressIndicator(),
                if (_message != null) Text(_message!),
              ],
            ),
          ),
        );
      },
    );
  }
}
