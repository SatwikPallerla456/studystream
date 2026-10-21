import 'package:flutter/material.dart';

import '../../data/db/app_database.dart';
import '../../domain/reader/reader_session_store.dart';

Future<void> showReaderPreferences({
  required BuildContext context,
  required AppDatabase database,
  String? libraryId,
  Item? item,
  int? currentPage,
  bool typography = true,
  ReaderPreferenceScope initialScope = ReaderPreferenceScope.title,
  Future<void> Function()? onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _ReaderPreferencesSheet(
    store: ReaderPreferencesStore(database, libraryId: libraryId, item: item),
    initialScope: initialScope,
    currentPage: currentPage,
    typography: typography,
    onChanged: onChanged,
  ),
);

class _ReaderPreferencesSheet extends StatefulWidget {
  const _ReaderPreferencesSheet({
    required this.store,
    required this.initialScope,
    required this.currentPage,
    required this.typography,
    this.onChanged,
  });
  final ReaderPreferencesStore store;
  final ReaderPreferenceScope initialScope;
  final int? currentPage;
  final bool typography;
  final Future<void> Function()? onChanged;
  @override
  State<_ReaderPreferencesSheet> createState() => _ReaderPreferencesState();
}

class _ReaderPreferencesState extends State<_ReaderPreferencesSheet> {
  late ReaderPreferenceScope _scope = widget.initialScope;
  ReaderPreferenceLayers? _layers;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final layers = await widget.store.layers();
      if (mounted)
        setState(() {
          _layers = layers;
          _error = null;
        });
    } on Object {
      if (mounted)
        setState(() => _error = 'Reading preferences could not load.');
    }
  }

  Future<void> _change({
    Map<String, dynamic> changes = const {},
    Set<String> reset = const {},
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.store.change(_scope, changes: changes, reset: reset);
      await _load();
      await widget.onChanged?.call();
    } on Object {
      if (mounted)
        setState(
          () => _error = 'The preference could not be applied. Try again.',
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layers = _layers;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .85,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reading preferences',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                SegmentedButton<ReaderPreferenceScope>(
                  segments: [
                    const ButtonSegment(
                      value: ReaderPreferenceScope.app,
                      label: Text('App'),
                    ),
                    if (widget.store.libraryId != null)
                      const ButtonSegment(
                        value: ReaderPreferenceScope.library,
                        label: Text('Library'),
                      ),
                    if (widget.store.item != null)
                      const ButtonSegment(
                        value: ReaderPreferenceScope.title,
                        label: Text('This title'),
                      ),
                  ],
                  selected: {_scope},
                  onSelectionChanged: _busy
                      ? null
                      : (value) => setState(() => _scope = value.first),
                ),
                const SizedBox(height: 12),
                Text(switch (_scope) {
                  ReaderPreferenceScope.app =>
                    'Defaults for all readers. Libraries and titles can override each preference.',
                  ReaderPreferenceScope.library =>
                    'Defaults for this library. Inherited values follow the app settings.',
                  ReaderPreferenceScope.title =>
                    'Overrides for this title. Inherited values follow library and app settings.',
                }),
                if (_busy || layers == null && _error == null)
                  const LinearProgressIndicator(),
                if (_error != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                if (layers != null) ...[
                  const SizedBox(height: 16),
                  _choice('mode', 'Page layout', {
                    'horizontal': 'Single page / chapter',
                    'spread': 'Two page spreads',
                    'vertical': 'Continuous vertical',
                  }),
                  _choice('rtl', 'Horizontal reading direction', {
                    false: 'Left to right',
                    true: 'Right to left',
                  }),
                  _choice('fit', 'Page fit', {
                    'contain': 'Fit page',
                    'fitWidth': 'Fit width',
                    'fill': 'Fill',
                  }),
                  _choice('background', 'Background', {
                    'black': 'Black',
                    'white': 'White',
                    'color': 'Single derived color',
                    'immersive': 'Immersive',
                  }),
                  _choice('coverSingle', 'First cover in spreads', {
                    true: 'Keep single',
                    false: 'Allow pairing',
                  }),
                  if (widget.typography) ...[
                    _choice('fontSize', 'Publication text size', {
                      for (var value = 12; value <= 36; value++)
                        value.toDouble(): '$value px',
                    }, numeric: true),
                    _choice('lineHeight', 'Publication line spacing', {
                      for (var value = 12; value <= 24; value++)
                        value / 10: '${(value / 10).toStringAsFixed(1)}×',
                    }, numeric: true),
                  ],
                  Text(
                    'Tap regions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'Leading and trailing edges follow the reading direction. Text selection and zoom take priority.',
                  ),
                  const SizedBox(height: 12),
                  for (final entry in {
                    'leadingEdgeAction': 'Leading edge',
                    'trailingEdgeAction': 'Trailing edge',
                    'topAction': 'Top region',
                    'centerAction': 'Center region',
                  }.entries)
                    _choice(entry.key, entry.value, {
                      'previous': 'Previous page',
                      'next': 'Next page',
                      'toggleChrome': 'Show / hide controls',
                      'study': 'Notes & bookmarks',
                      'none': 'No action',
                    }),
                  if (_scope == ReaderPreferenceScope.title &&
                      widget.currentPage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Pairing for page ${widget.currentPage}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    _pairing('singlePages', 'Keep this page single'),
                    _pairing('pairingStarts', 'Start a pair at this page'),
                  ],
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _change(
                            reset: _scope == ReaderPreferenceScope.title
                                ? ReaderSessionStore.settingKeys
                                : ReaderPreferencesStore.sharedKeys,
                          ),
                    icon: const Icon(Icons.restore),
                    label: Text(
                      _scope == ReaderPreferenceScope.app
                          ? 'Restore app reader defaults'
                          : 'Reset this layer to inherited defaults',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _choice(
    String key,
    String title,
    Map<Object, String> choices, {
    bool numeric = false,
  }) {
    final own = _layers!.own(_scope)[key];
    final resolved = _layers!.inherited(_scope)[key];
    Object? normalize(Object? value) =>
        numeric && value is num ? value.toDouble() : value;
    final options = <Object, String>{...choices};
    if (own != null && !options.containsKey(normalize(own)))
      options[normalize(own)!] = '$own';
    final selected = own == null ? 'inherit' : normalize(own)!;
    final inheritedLabel = _scope == ReaderPreferenceScope.app
        ? 'Built-in default'
        : 'Inherit';
    final effective = options[normalize(resolved)] ?? '$resolved';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<Object>(
        key: ValueKey('$_scope:$key:$selected'),
        initialValue: selected,
        isExpanded: true,
        decoration: InputDecoration(labelText: title),
        items: [
          DropdownMenuItem(
            value: 'inherit',
            child: Text(
              '$inheritedLabel · $effective',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final entry in options.entries)
            DropdownMenuItem(value: entry.key, child: Text(entry.value)),
        ],
        onChanged: _busy
            ? null
            : (value) => value == 'inherit'
                  ? _change(reset: {key})
                  : _change(changes: {key: value}),
      ),
    );
  }

  Widget _pairing(String key, String label) {
    final pages = List<int>.from(_layers!.title[key] as List? ?? []);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: pages.contains(widget.currentPage),
      onChanged: _busy
          ? null
          : (enabled) {
              final current = widget.currentPage!;
              enabled ? pages.add(current) : pages.remove(current);
              _change(changes: {key: pages});
            },
    );
  }
}
