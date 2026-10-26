import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/reader/book_page_source.dart';
import '../../data/reader/publication_content.dart';
import '../../domain/reader/reader_jobs.dart';

Future<PublicationSearchHit?> showPublicationSearch({
  required BuildContext context,
  required ArchiveBookSource source,
  required String revision,
  required ReaderJobScheduler jobs,
}) => showModalBottomSheet<PublicationSearchHit>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) =>
      _PublicationSearch(source: source, revision: revision, jobs: jobs),
);

class _PublicationSearch extends StatefulWidget {
  const _PublicationSearch({
    required this.source,
    required this.revision,
    required this.jobs,
  });
  final ArchiveBookSource source;
  final String revision;
  final ReaderJobScheduler jobs;
  @override
  State<_PublicationSearch> createState() => _PublicationSearchState();
}

class _PublicationSearchState extends State<_PublicationSearch> {
  final _query = TextEditingController();
  final _hits = <PublicationSearchHit>[];
  final _skipped = <int>{};
  ReaderLease<PublicationSearchBatch>? _lease;
  int _generation = 0, _offset = 0;
  int? _next;
  bool _busy = false, _searched = false;
  String? _error;
  void _changed() {
    _generation++;
    _lease?.release();
    _lease = null;
    setState(() {
      _busy = false;
      _searched = false;
      _hits.clear();
      _skipped.clear();
      _next = null;
      _offset = 0;
      _error = null;
    });
  }

  Future<void> _search({bool more = false}) async {
    final query = _query.text.trim();
    if (_busy || query.isEmpty || query.length > 200) return;
    final generation = ++_generation;
    final page = more ? _next : 1;
    if (page == null) return;
    final offset = more ? _offset : 0;
    setState(() {
      _busy = true;
      _searched = true;
      _error = null;
      if (!more) {
        _hits.clear();
        _skipped.clear();
      }
    });
    final lease = widget.jobs.request<PublicationSearchBatch>(
      key: 'search:${widget.revision}:$generation:$page:$offset:$query',
      priority: ReaderPriority.analysis,
      estimatedBytes: 32 * 1024 * 1024,
      run: (token) => widget.source.search(
        query,
        startPage: page,
        startOffset: offset,
        cancellation: token,
      ),
    );
    _lease = lease;
    try {
      final batch = await lease.future;
      if (!mounted || generation != _generation) return;
      setState(() {
        _hits.addAll(batch.hits.take(480 - _hits.length));
        _skipped.addAll(batch.skipped);
        _next = batch.nextPage;
        _offset = batch.nextOffset;
        _busy = false;
      });
    } on ReaderCancelled {
      if (mounted && generation == _generation)
        setState(() {
          _busy = false;
          _error = 'Search paused. Search again to continue.';
        });
    } catch (_) {
      if (mounted && generation == _generation)
        setState(() {
          _busy = false;
          _error =
              'Search could not finish. Check the publication and try again.';
        });
    } finally {
      lease.release();
      if (identical(_lease, lease)) _lease = null;
    }
  }

  @override
  void dispose() {
    _generation++;
    _lease?.release();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(
        children: [
          ListTile(
            title: const Text('Search this book'),
            subtitle: const Text(
              'Search publication text. Scanned images require OCR.',
            ),
            trailing: IconButton(
              tooltip: 'Close search',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _query,
              autofocus: true,
              maxLength: 200,
              textInputAction: TextInputAction.search,
              onChanged: (_) => _changed(),
              onSubmitted: (_) => unawaited(_search()),
              decoration: InputDecoration(
                labelText: 'Words or phrase',
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _busy ? null : () => unawaited(_search()),
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          if (_searched && !_busy)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${_hits.length} matches${_next != null ? ' · more sections available' : ' · search complete'}'
                '${_skipped.isEmpty ? '' : ' · ${_skipped.length} sections could not be searched'}',
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _hits.length,
              itemBuilder: (context, index) {
                final hit = _hits[index];
                return ListTile(
                  title: Text(widget.source.titles[hit.page - 1]),
                  subtitle: Text(hit.excerpt),
                  trailing: Text('${hit.page}'),
                  onTap: () => Navigator.pop(context, hit),
                );
              },
            ),
          ),
          if (_next != null && _hits.length < 480)
            Padding(
              padding: const EdgeInsets.all(8),
              child: FilledButton(
                onPressed: _busy ? null : () => unawaited(_search(more: true)),
                child: const Text('Search more'),
              ),
            ),
          if (_hits.length >= 480)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Refine your phrase to narrow these results.'),
            ),
        ],
      ),
    ),
  );
}
