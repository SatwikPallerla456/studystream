import 'package:drift/drift.dart';

enum BrowseSort {
  natural('Original order'),
  title('Title A–Z'),
  titleDescending('Title Z–A'),
  newest('Newest added'),
  oldest('Oldest added'),
  recent('Recently opened');

  const BrowseSort(this.label);
  final String label;
}

String catalogTerms(String query) => query
    .trim()
    .split(RegExp(r'\s+'))
    .where((t) => t.isNotEmpty)
    .take(8)
    .map((t) => '"${t.replaceAll('"', '""')}"*')
    .join(' AND ');

/// Item alias is fixed by the caller's own SQL, never supplied by user input.
({List<String> sql, List<Variable> values}) organizationWhere({
  bool favorites = false,
  String? tag,
}) => (
  sql: [
    if (favorites)
      "EXISTS(SELECT 1 FROM media_records o WHERE o.id='organization:'||i.id AND o.item_id=i.id AND o.deleted=0 AND json_extract(o.payload,'\$.favorite')=1)",
    if (tag != null && tag.isNotEmpty)
      "EXISTS(SELECT 1 FROM media_records o,json_each(o.payload,'\$.tags') t WHERE o.id='organization:'||i.id AND o.item_id=i.id AND o.deleted=0 AND t.value=? COLLATE NOCASE)",
  ],
  values: [if (tag != null && tag.isNotEmpty) Variable(tag)],
);

String browseItemOrder(
  BrowseSort sort, {
  String natural = 'lower(COALESCE(s.title,i.user_title,i.title))',
}) => switch (sort) {
  BrowseSort.natural => natural,
  BrowseSort.title ||
  BrowseSort.titleDescending => 'lower(COALESCE(s.title,i.user_title,i.title))',
  BrowseSort.newest => "printf('%020d',9999999999999-i.created_at)",
  BrowseSort.oldest => "printf('%020d',i.created_at)",
  BrowseSort.recent =>
    "printf('%020d',9999999999999-MAX(COALESCE(p.last_opened_at,0),COALESCE(r.last_opened_at,0)))",
};
