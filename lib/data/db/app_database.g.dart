// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LibrariesTable extends Libraries
    with TableInfo<$LibrariesTable, Library> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LibrariesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _rootFolderPathMeta = const VerificationMeta(
    'rootFolderPath',
  );
  @override
  late final GeneratedColumn<String> rootFolderPath = GeneratedColumn<String>(
    'root_folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _coverPathMeta = const VerificationMeta(
    'coverPath',
  );
  @override
  late final GeneratedColumn<String> coverPath = GeneratedColumn<String>(
    'cover_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastScannedAtMeta = const VerificationMeta(
    'lastScannedAt',
  );
  @override
  late final GeneratedColumn<int> lastScannedAt = GeneratedColumn<int>(
    'last_scanned_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unavailableMeta = const VerificationMeta(
    'unavailable',
  );
  @override
  late final GeneratedColumn<bool> unavailable = GeneratedColumn<bool>(
    'unavailable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unavailable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _updatedByDeviceMeta = const VerificationMeta(
    'updatedByDevice',
  );
  @override
  late final GeneratedColumn<String> updatedByDevice = GeneratedColumn<String>(
    'updated_by_device',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    rootFolderPath,
    coverPath,
    createdAt,
    updatedAt,
    lastScannedAt,
    unavailable,
    version,
    updatedByDevice,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'libraries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Library> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('root_folder_path')) {
      context.handle(
        _rootFolderPathMeta,
        rootFolderPath.isAcceptableOrUnknown(
          data['root_folder_path']!,
          _rootFolderPathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rootFolderPathMeta);
    }
    if (data.containsKey('cover_path')) {
      context.handle(
        _coverPathMeta,
        coverPath.isAcceptableOrUnknown(data['cover_path']!, _coverPathMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_scanned_at')) {
      context.handle(
        _lastScannedAtMeta,
        lastScannedAt.isAcceptableOrUnknown(
          data['last_scanned_at']!,
          _lastScannedAtMeta,
        ),
      );
    }
    if (data.containsKey('unavailable')) {
      context.handle(
        _unavailableMeta,
        unavailable.isAcceptableOrUnknown(
          data['unavailable']!,
          _unavailableMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('updated_by_device')) {
      context.handle(
        _updatedByDeviceMeta,
        updatedByDevice.isAcceptableOrUnknown(
          data['updated_by_device']!,
          _updatedByDeviceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Library map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Library(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      rootFolderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_folder_path'],
      )!,
      coverPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cover_path'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      lastScannedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_scanned_at'],
      ),
      unavailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unavailable'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      updatedByDevice: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_by_device'],
      )!,
    );
  }

  @override
  $LibrariesTable createAlias(String alias) {
    return $LibrariesTable(attachedDatabase, alias);
  }
}

class Library extends DataClass implements Insertable<Library> {
  final String id;
  final String title;
  final String description;
  final String rootFolderPath;
  final String? coverPath;
  final int createdAt;
  final int updatedAt;
  final int? lastScannedAt;
  final bool unavailable;
  final int version;
  final String updatedByDevice;
  const Library({
    required this.id,
    required this.title,
    required this.description,
    required this.rootFolderPath,
    this.coverPath,
    required this.createdAt,
    required this.updatedAt,
    this.lastScannedAt,
    required this.unavailable,
    required this.version,
    required this.updatedByDevice,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['description'] = Variable<String>(description);
    map['root_folder_path'] = Variable<String>(rootFolderPath);
    if (!nullToAbsent || coverPath != null) {
      map['cover_path'] = Variable<String>(coverPath);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || lastScannedAt != null) {
      map['last_scanned_at'] = Variable<int>(lastScannedAt);
    }
    map['unavailable'] = Variable<bool>(unavailable);
    map['version'] = Variable<int>(version);
    map['updated_by_device'] = Variable<String>(updatedByDevice);
    return map;
  }

  LibrariesCompanion toCompanion(bool nullToAbsent) {
    return LibrariesCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      rootFolderPath: Value(rootFolderPath),
      coverPath: coverPath == null && nullToAbsent
          ? const Value.absent()
          : Value(coverPath),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastScannedAt: lastScannedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastScannedAt),
      unavailable: Value(unavailable),
      version: Value(version),
      updatedByDevice: Value(updatedByDevice),
    );
  }

  factory Library.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Library(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String>(json['description']),
      rootFolderPath: serializer.fromJson<String>(json['rootFolderPath']),
      coverPath: serializer.fromJson<String?>(json['coverPath']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      lastScannedAt: serializer.fromJson<int?>(json['lastScannedAt']),
      unavailable: serializer.fromJson<bool>(json['unavailable']),
      version: serializer.fromJson<int>(json['version']),
      updatedByDevice: serializer.fromJson<String>(json['updatedByDevice']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String>(description),
      'rootFolderPath': serializer.toJson<String>(rootFolderPath),
      'coverPath': serializer.toJson<String?>(coverPath),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'lastScannedAt': serializer.toJson<int?>(lastScannedAt),
      'unavailable': serializer.toJson<bool>(unavailable),
      'version': serializer.toJson<int>(version),
      'updatedByDevice': serializer.toJson<String>(updatedByDevice),
    };
  }

  Library copyWith({
    String? id,
    String? title,
    String? description,
    String? rootFolderPath,
    Value<String?> coverPath = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    Value<int?> lastScannedAt = const Value.absent(),
    bool? unavailable,
    int? version,
    String? updatedByDevice,
  }) => Library(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    rootFolderPath: rootFolderPath ?? this.rootFolderPath,
    coverPath: coverPath.present ? coverPath.value : this.coverPath,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastScannedAt: lastScannedAt.present
        ? lastScannedAt.value
        : this.lastScannedAt,
    unavailable: unavailable ?? this.unavailable,
    version: version ?? this.version,
    updatedByDevice: updatedByDevice ?? this.updatedByDevice,
  );
  Library copyWithCompanion(LibrariesCompanion data) {
    return Library(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      rootFolderPath: data.rootFolderPath.present
          ? data.rootFolderPath.value
          : this.rootFolderPath,
      coverPath: data.coverPath.present ? data.coverPath.value : this.coverPath,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastScannedAt: data.lastScannedAt.present
          ? data.lastScannedAt.value
          : this.lastScannedAt,
      unavailable: data.unavailable.present
          ? data.unavailable.value
          : this.unavailable,
      version: data.version.present ? data.version.value : this.version,
      updatedByDevice: data.updatedByDevice.present
          ? data.updatedByDevice.value
          : this.updatedByDevice,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Library(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('rootFolderPath: $rootFolderPath, ')
          ..write('coverPath: $coverPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastScannedAt: $lastScannedAt, ')
          ..write('unavailable: $unavailable, ')
          ..write('version: $version, ')
          ..write('updatedByDevice: $updatedByDevice')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    rootFolderPath,
    coverPath,
    createdAt,
    updatedAt,
    lastScannedAt,
    unavailable,
    version,
    updatedByDevice,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Library &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.rootFolderPath == this.rootFolderPath &&
          other.coverPath == this.coverPath &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastScannedAt == this.lastScannedAt &&
          other.unavailable == this.unavailable &&
          other.version == this.version &&
          other.updatedByDevice == this.updatedByDevice);
}

class LibrariesCompanion extends UpdateCompanion<Library> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> description;
  final Value<String> rootFolderPath;
  final Value<String?> coverPath;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> lastScannedAt;
  final Value<bool> unavailable;
  final Value<int> version;
  final Value<String> updatedByDevice;
  final Value<int> rowid;
  const LibrariesCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.rootFolderPath = const Value.absent(),
    this.coverPath = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastScannedAt = const Value.absent(),
    this.unavailable = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedByDevice = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LibrariesCompanion.insert({
    required String id,
    required String title,
    this.description = const Value.absent(),
    required String rootFolderPath,
    this.coverPath = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.lastScannedAt = const Value.absent(),
    this.unavailable = const Value.absent(),
    this.version = const Value.absent(),
    this.updatedByDevice = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       rootFolderPath = Value(rootFolderPath),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Library> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<String>? rootFolderPath,
    Expression<String>? coverPath,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? lastScannedAt,
    Expression<bool>? unavailable,
    Expression<int>? version,
    Expression<String>? updatedByDevice,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (rootFolderPath != null) 'root_folder_path': rootFolderPath,
      if (coverPath != null) 'cover_path': coverPath,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastScannedAt != null) 'last_scanned_at': lastScannedAt,
      if (unavailable != null) 'unavailable': unavailable,
      if (version != null) 'version': version,
      if (updatedByDevice != null) 'updated_by_device': updatedByDevice,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LibrariesCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? description,
    Value<String>? rootFolderPath,
    Value<String?>? coverPath,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int?>? lastScannedAt,
    Value<bool>? unavailable,
    Value<int>? version,
    Value<String>? updatedByDevice,
    Value<int>? rowid,
  }) {
    return LibrariesCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      rootFolderPath: rootFolderPath ?? this.rootFolderPath,
      coverPath: coverPath ?? this.coverPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
      unavailable: unavailable ?? this.unavailable,
      version: version ?? this.version,
      updatedByDevice: updatedByDevice ?? this.updatedByDevice,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (rootFolderPath.present) {
      map['root_folder_path'] = Variable<String>(rootFolderPath.value);
    }
    if (coverPath.present) {
      map['cover_path'] = Variable<String>(coverPath.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (lastScannedAt.present) {
      map['last_scanned_at'] = Variable<int>(lastScannedAt.value);
    }
    if (unavailable.present) {
      map['unavailable'] = Variable<bool>(unavailable.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (updatedByDevice.present) {
      map['updated_by_device'] = Variable<String>(updatedByDevice.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LibrariesCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('rootFolderPath: $rootFolderPath, ')
          ..write('coverPath: $coverPath, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastScannedAt: $lastScannedAt, ')
          ..write('unavailable: $unavailable, ')
          ..write('version: $version, ')
          ..write('updatedByDevice: $updatedByDevice, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SectionsTable extends Sections with TableInfo<$SectionsTable, Section> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryIdMeta = const VerificationMeta(
    'libraryId',
  );
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
    'library_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES libraries (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _parentSectionIdMeta = const VerificationMeta(
    'parentSectionId',
  );
  @override
  late final GeneratedColumn<String> parentSectionId = GeneratedColumn<String>(
    'parent_section_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _folderPathMeta = const VerificationMeta(
    'folderPath',
  );
  @override
  late final GeneratedColumn<String> folderPath = GeneratedColumn<String>(
    'folder_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedCountMeta = const VerificationMeta(
    'completedCount',
  );
  @override
  late final GeneratedColumn<int> completedCount = GeneratedColumn<int>(
    'completed_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _unavailableMeta = const VerificationMeta(
    'unavailable',
  );
  @override
  late final GeneratedColumn<bool> unavailable = GeneratedColumn<bool>(
    'unavailable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unavailable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    libraryId,
    title,
    relativePath,
    parentSectionId,
    orderIndex,
    folderPath,
    itemCount,
    completedCount,
    unavailable,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sections';
  @override
  VerificationContext validateIntegrity(
    Insertable<Section> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('library_id')) {
      context.handle(
        _libraryIdMeta,
        libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_libraryIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    }
    if (data.containsKey('parent_section_id')) {
      context.handle(
        _parentSectionIdMeta,
        parentSectionId.isAcceptableOrUnknown(
          data['parent_section_id']!,
          _parentSectionIdMeta,
        ),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('folder_path')) {
      context.handle(
        _folderPathMeta,
        folderPath.isAcceptableOrUnknown(data['folder_path']!, _folderPathMeta),
      );
    } else if (isInserting) {
      context.missing(_folderPathMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    }
    if (data.containsKey('completed_count')) {
      context.handle(
        _completedCountMeta,
        completedCount.isAcceptableOrUnknown(
          data['completed_count']!,
          _completedCountMeta,
        ),
      );
    }
    if (data.containsKey('unavailable')) {
      context.handle(
        _unavailableMeta,
        unavailable.isAcceptableOrUnknown(
          data['unavailable']!,
          _unavailableMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Section map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Section(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      libraryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      parentSectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_section_id'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      folderPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_path'],
      )!,
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
      completedCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_count'],
      )!,
      unavailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unavailable'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SectionsTable createAlias(String alias) {
    return $SectionsTable(attachedDatabase, alias);
  }
}

class Section extends DataClass implements Insertable<Section> {
  final String id;
  final String libraryId;
  final String title;
  final String relativePath;
  final String? parentSectionId;
  final int orderIndex;
  final String folderPath;
  final int itemCount;
  final int completedCount;
  final bool unavailable;
  final int updatedAt;
  const Section({
    required this.id,
    required this.libraryId,
    required this.title,
    required this.relativePath,
    this.parentSectionId,
    required this.orderIndex,
    required this.folderPath,
    required this.itemCount,
    required this.completedCount,
    required this.unavailable,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['library_id'] = Variable<String>(libraryId);
    map['title'] = Variable<String>(title);
    map['relative_path'] = Variable<String>(relativePath);
    if (!nullToAbsent || parentSectionId != null) {
      map['parent_section_id'] = Variable<String>(parentSectionId);
    }
    map['order_index'] = Variable<int>(orderIndex);
    map['folder_path'] = Variable<String>(folderPath);
    map['item_count'] = Variable<int>(itemCount);
    map['completed_count'] = Variable<int>(completedCount);
    map['unavailable'] = Variable<bool>(unavailable);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SectionsCompanion toCompanion(bool nullToAbsent) {
    return SectionsCompanion(
      id: Value(id),
      libraryId: Value(libraryId),
      title: Value(title),
      relativePath: Value(relativePath),
      parentSectionId: parentSectionId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentSectionId),
      orderIndex: Value(orderIndex),
      folderPath: Value(folderPath),
      itemCount: Value(itemCount),
      completedCount: Value(completedCount),
      unavailable: Value(unavailable),
      updatedAt: Value(updatedAt),
    );
  }

  factory Section.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Section(
      id: serializer.fromJson<String>(json['id']),
      libraryId: serializer.fromJson<String>(json['libraryId']),
      title: serializer.fromJson<String>(json['title']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      parentSectionId: serializer.fromJson<String?>(json['parentSectionId']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      folderPath: serializer.fromJson<String>(json['folderPath']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      completedCount: serializer.fromJson<int>(json['completedCount']),
      unavailable: serializer.fromJson<bool>(json['unavailable']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'libraryId': serializer.toJson<String>(libraryId),
      'title': serializer.toJson<String>(title),
      'relativePath': serializer.toJson<String>(relativePath),
      'parentSectionId': serializer.toJson<String?>(parentSectionId),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'folderPath': serializer.toJson<String>(folderPath),
      'itemCount': serializer.toJson<int>(itemCount),
      'completedCount': serializer.toJson<int>(completedCount),
      'unavailable': serializer.toJson<bool>(unavailable),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  Section copyWith({
    String? id,
    String? libraryId,
    String? title,
    String? relativePath,
    Value<String?> parentSectionId = const Value.absent(),
    int? orderIndex,
    String? folderPath,
    int? itemCount,
    int? completedCount,
    bool? unavailable,
    int? updatedAt,
  }) => Section(
    id: id ?? this.id,
    libraryId: libraryId ?? this.libraryId,
    title: title ?? this.title,
    relativePath: relativePath ?? this.relativePath,
    parentSectionId: parentSectionId.present
        ? parentSectionId.value
        : this.parentSectionId,
    orderIndex: orderIndex ?? this.orderIndex,
    folderPath: folderPath ?? this.folderPath,
    itemCount: itemCount ?? this.itemCount,
    completedCount: completedCount ?? this.completedCount,
    unavailable: unavailable ?? this.unavailable,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Section copyWithCompanion(SectionsCompanion data) {
    return Section(
      id: data.id.present ? data.id.value : this.id,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      title: data.title.present ? data.title.value : this.title,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      parentSectionId: data.parentSectionId.present
          ? data.parentSectionId.value
          : this.parentSectionId,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      folderPath: data.folderPath.present
          ? data.folderPath.value
          : this.folderPath,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      completedCount: data.completedCount.present
          ? data.completedCount.value
          : this.completedCount,
      unavailable: data.unavailable.present
          ? data.unavailable.value
          : this.unavailable,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Section(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('title: $title, ')
          ..write('relativePath: $relativePath, ')
          ..write('parentSectionId: $parentSectionId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('folderPath: $folderPath, ')
          ..write('itemCount: $itemCount, ')
          ..write('completedCount: $completedCount, ')
          ..write('unavailable: $unavailable, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    libraryId,
    title,
    relativePath,
    parentSectionId,
    orderIndex,
    folderPath,
    itemCount,
    completedCount,
    unavailable,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Section &&
          other.id == this.id &&
          other.libraryId == this.libraryId &&
          other.title == this.title &&
          other.relativePath == this.relativePath &&
          other.parentSectionId == this.parentSectionId &&
          other.orderIndex == this.orderIndex &&
          other.folderPath == this.folderPath &&
          other.itemCount == this.itemCount &&
          other.completedCount == this.completedCount &&
          other.unavailable == this.unavailable &&
          other.updatedAt == this.updatedAt);
}

class SectionsCompanion extends UpdateCompanion<Section> {
  final Value<String> id;
  final Value<String> libraryId;
  final Value<String> title;
  final Value<String> relativePath;
  final Value<String?> parentSectionId;
  final Value<int> orderIndex;
  final Value<String> folderPath;
  final Value<int> itemCount;
  final Value<int> completedCount;
  final Value<bool> unavailable;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SectionsCompanion({
    this.id = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.title = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.parentSectionId = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.folderPath = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.completedCount = const Value.absent(),
    this.unavailable = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SectionsCompanion.insert({
    required String id,
    required String libraryId,
    required String title,
    this.relativePath = const Value.absent(),
    this.parentSectionId = const Value.absent(),
    required int orderIndex,
    required String folderPath,
    this.itemCount = const Value.absent(),
    this.completedCount = const Value.absent(),
    this.unavailable = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       libraryId = Value(libraryId),
       title = Value(title),
       orderIndex = Value(orderIndex),
       folderPath = Value(folderPath);
  static Insertable<Section> custom({
    Expression<String>? id,
    Expression<String>? libraryId,
    Expression<String>? title,
    Expression<String>? relativePath,
    Expression<String>? parentSectionId,
    Expression<int>? orderIndex,
    Expression<String>? folderPath,
    Expression<int>? itemCount,
    Expression<int>? completedCount,
    Expression<bool>? unavailable,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (libraryId != null) 'library_id': libraryId,
      if (title != null) 'title': title,
      if (relativePath != null) 'relative_path': relativePath,
      if (parentSectionId != null) 'parent_section_id': parentSectionId,
      if (orderIndex != null) 'order_index': orderIndex,
      if (folderPath != null) 'folder_path': folderPath,
      if (itemCount != null) 'item_count': itemCount,
      if (completedCount != null) 'completed_count': completedCount,
      if (unavailable != null) 'unavailable': unavailable,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SectionsCompanion copyWith({
    Value<String>? id,
    Value<String>? libraryId,
    Value<String>? title,
    Value<String>? relativePath,
    Value<String?>? parentSectionId,
    Value<int>? orderIndex,
    Value<String>? folderPath,
    Value<int>? itemCount,
    Value<int>? completedCount,
    Value<bool>? unavailable,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SectionsCompanion(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      title: title ?? this.title,
      relativePath: relativePath ?? this.relativePath,
      parentSectionId: parentSectionId ?? this.parentSectionId,
      orderIndex: orderIndex ?? this.orderIndex,
      folderPath: folderPath ?? this.folderPath,
      itemCount: itemCount ?? this.itemCount,
      completedCount: completedCount ?? this.completedCount,
      unavailable: unavailable ?? this.unavailable,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (parentSectionId.present) {
      map['parent_section_id'] = Variable<String>(parentSectionId.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (folderPath.present) {
      map['folder_path'] = Variable<String>(folderPath.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (completedCount.present) {
      map['completed_count'] = Variable<int>(completedCount.value);
    }
    if (unavailable.present) {
      map['unavailable'] = Variable<bool>(unavailable.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SectionsCompanion(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('title: $title, ')
          ..write('relativePath: $relativePath, ')
          ..write('parentSectionId: $parentSectionId, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('folderPath: $folderPath, ')
          ..write('itemCount: $itemCount, ')
          ..write('completedCount: $completedCount, ')
          ..write('unavailable: $unavailable, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ItemsTable extends Items with TableInfo<$ItemsTable, Item> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryIdMeta = const VerificationMeta(
    'libraryId',
  );
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
    'library_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES libraries (id)',
    ),
  );
  static const VerificationMeta _sectionIdMeta = const VerificationMeta(
    'sectionId',
  );
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
    'section_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sections (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userTitleMeta = const VerificationMeta(
    'userTitle',
  );
  @override
  late final GeneratedColumn<String> userTitle = GeneratedColumn<String>(
    'user_title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemTypeMeta = const VerificationMeta(
    'itemType',
  );
  @override
  late final GeneratedColumn<String> itemType = GeneratedColumn<String>(
    'item_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<double> durationSeconds = GeneratedColumn<double>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageCountMeta = const VerificationMeta(
    'pageCount',
  );
  @override
  late final GeneratedColumn<int> pageCount = GeneratedColumn<int>(
    'page_count',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailPathMeta = const VerificationMeta(
    'thumbnailPath',
  );
  @override
  late final GeneratedColumn<String> thumbnailPath = GeneratedColumn<String>(
    'thumbnail_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modifiedAtMeta = const VerificationMeta(
    'modifiedAt',
  );
  @override
  late final GeneratedColumn<int> modifiedAt = GeneratedColumn<int>(
    'modified_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unavailableMeta = const VerificationMeta(
    'unavailable',
  );
  @override
  late final GeneratedColumn<bool> unavailable = GeneratedColumn<bool>(
    'unavailable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("unavailable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    libraryId,
    sectionId,
    title,
    userTitle,
    filename,
    filePath,
    relativePath,
    itemType,
    orderIndex,
    durationSeconds,
    pageCount,
    thumbnailPath,
    modifiedAt,
    fileSize,
    fingerprint,
    unavailable,
    createdAt,
    updatedAt,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(
    Insertable<Item> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('library_id')) {
      context.handle(
        _libraryIdMeta,
        libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_libraryIdMeta);
    }
    if (data.containsKey('section_id')) {
      context.handle(
        _sectionIdMeta,
        sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sectionIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('user_title')) {
      context.handle(
        _userTitleMeta,
        userTitle.isAcceptableOrUnknown(data['user_title']!, _userTitleMeta),
      );
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('item_type')) {
      context.handle(
        _itemTypeMeta,
        itemType.isAcceptableOrUnknown(data['item_type']!, _itemTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_itemTypeMeta);
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIndexMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('page_count')) {
      context.handle(
        _pageCountMeta,
        pageCount.isAcceptableOrUnknown(data['page_count']!, _pageCountMeta),
      );
    }
    if (data.containsKey('thumbnail_path')) {
      context.handle(
        _thumbnailPathMeta,
        thumbnailPath.isAcceptableOrUnknown(
          data['thumbnail_path']!,
          _thumbnailPathMeta,
        ),
      );
    }
    if (data.containsKey('modified_at')) {
      context.handle(
        _modifiedAtMeta,
        modifiedAt.isAcceptableOrUnknown(data['modified_at']!, _modifiedAtMeta),
      );
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    }
    if (data.containsKey('unavailable')) {
      context.handle(
        _unavailableMeta,
        unavailable.isAcceptableOrUnknown(
          data['unavailable']!,
          _unavailableMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Item map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Item(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      libraryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_id'],
      )!,
      sectionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}section_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      userTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_title'],
      ),
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      itemType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_type'],
      )!,
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration_seconds'],
      ),
      pageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_count'],
      ),
      thumbnailPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumbnail_path'],
      ),
      modifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}modified_at'],
      ),
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      ),
      unavailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}unavailable'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class Item extends DataClass implements Insertable<Item> {
  final String id;
  final String libraryId;
  final String sectionId;
  final String title;
  final String? userTitle;
  final String filename;
  final String filePath;
  final String relativePath;
  final String itemType;
  final int orderIndex;
  final double? durationSeconds;
  final int? pageCount;
  final String? thumbnailPath;
  final int? modifiedAt;
  final int? fileSize;
  final String? fingerprint;
  final bool unavailable;
  final int createdAt;
  final int updatedAt;
  final int version;
  const Item({
    required this.id,
    required this.libraryId,
    required this.sectionId,
    required this.title,
    this.userTitle,
    required this.filename,
    required this.filePath,
    required this.relativePath,
    required this.itemType,
    required this.orderIndex,
    this.durationSeconds,
    this.pageCount,
    this.thumbnailPath,
    this.modifiedAt,
    this.fileSize,
    this.fingerprint,
    required this.unavailable,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['library_id'] = Variable<String>(libraryId);
    map['section_id'] = Variable<String>(sectionId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || userTitle != null) {
      map['user_title'] = Variable<String>(userTitle);
    }
    map['filename'] = Variable<String>(filename);
    map['file_path'] = Variable<String>(filePath);
    map['relative_path'] = Variable<String>(relativePath);
    map['item_type'] = Variable<String>(itemType);
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<double>(durationSeconds);
    }
    if (!nullToAbsent || pageCount != null) {
      map['page_count'] = Variable<int>(pageCount);
    }
    if (!nullToAbsent || thumbnailPath != null) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath);
    }
    if (!nullToAbsent || modifiedAt != null) {
      map['modified_at'] = Variable<int>(modifiedAt);
    }
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    if (!nullToAbsent || fingerprint != null) {
      map['fingerprint'] = Variable<String>(fingerprint);
    }
    map['unavailable'] = Variable<bool>(unavailable);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['version'] = Variable<int>(version);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      libraryId: Value(libraryId),
      sectionId: Value(sectionId),
      title: Value(title),
      userTitle: userTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(userTitle),
      filename: Value(filename),
      filePath: Value(filePath),
      relativePath: Value(relativePath),
      itemType: Value(itemType),
      orderIndex: Value(orderIndex),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      pageCount: pageCount == null && nullToAbsent
          ? const Value.absent()
          : Value(pageCount),
      thumbnailPath: thumbnailPath == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnailPath),
      modifiedAt: modifiedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(modifiedAt),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      fingerprint: fingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(fingerprint),
      unavailable: Value(unavailable),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      version: Value(version),
    );
  }

  factory Item.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Item(
      id: serializer.fromJson<String>(json['id']),
      libraryId: serializer.fromJson<String>(json['libraryId']),
      sectionId: serializer.fromJson<String>(json['sectionId']),
      title: serializer.fromJson<String>(json['title']),
      userTitle: serializer.fromJson<String?>(json['userTitle']),
      filename: serializer.fromJson<String>(json['filename']),
      filePath: serializer.fromJson<String>(json['filePath']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      itemType: serializer.fromJson<String>(json['itemType']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      durationSeconds: serializer.fromJson<double?>(json['durationSeconds']),
      pageCount: serializer.fromJson<int?>(json['pageCount']),
      thumbnailPath: serializer.fromJson<String?>(json['thumbnailPath']),
      modifiedAt: serializer.fromJson<int?>(json['modifiedAt']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      fingerprint: serializer.fromJson<String?>(json['fingerprint']),
      unavailable: serializer.fromJson<bool>(json['unavailable']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'libraryId': serializer.toJson<String>(libraryId),
      'sectionId': serializer.toJson<String>(sectionId),
      'title': serializer.toJson<String>(title),
      'userTitle': serializer.toJson<String?>(userTitle),
      'filename': serializer.toJson<String>(filename),
      'filePath': serializer.toJson<String>(filePath),
      'relativePath': serializer.toJson<String>(relativePath),
      'itemType': serializer.toJson<String>(itemType),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'durationSeconds': serializer.toJson<double?>(durationSeconds),
      'pageCount': serializer.toJson<int?>(pageCount),
      'thumbnailPath': serializer.toJson<String?>(thumbnailPath),
      'modifiedAt': serializer.toJson<int?>(modifiedAt),
      'fileSize': serializer.toJson<int?>(fileSize),
      'fingerprint': serializer.toJson<String?>(fingerprint),
      'unavailable': serializer.toJson<bool>(unavailable),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'version': serializer.toJson<int>(version),
    };
  }

  Item copyWith({
    String? id,
    String? libraryId,
    String? sectionId,
    String? title,
    Value<String?> userTitle = const Value.absent(),
    String? filename,
    String? filePath,
    String? relativePath,
    String? itemType,
    int? orderIndex,
    Value<double?> durationSeconds = const Value.absent(),
    Value<int?> pageCount = const Value.absent(),
    Value<String?> thumbnailPath = const Value.absent(),
    Value<int?> modifiedAt = const Value.absent(),
    Value<int?> fileSize = const Value.absent(),
    Value<String?> fingerprint = const Value.absent(),
    bool? unavailable,
    int? createdAt,
    int? updatedAt,
    int? version,
  }) => Item(
    id: id ?? this.id,
    libraryId: libraryId ?? this.libraryId,
    sectionId: sectionId ?? this.sectionId,
    title: title ?? this.title,
    userTitle: userTitle.present ? userTitle.value : this.userTitle,
    filename: filename ?? this.filename,
    filePath: filePath ?? this.filePath,
    relativePath: relativePath ?? this.relativePath,
    itemType: itemType ?? this.itemType,
    orderIndex: orderIndex ?? this.orderIndex,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    pageCount: pageCount.present ? pageCount.value : this.pageCount,
    thumbnailPath: thumbnailPath.present
        ? thumbnailPath.value
        : this.thumbnailPath,
    modifiedAt: modifiedAt.present ? modifiedAt.value : this.modifiedAt,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    fingerprint: fingerprint.present ? fingerprint.value : this.fingerprint,
    unavailable: unavailable ?? this.unavailable,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
  );
  Item copyWithCompanion(ItemsCompanion data) {
    return Item(
      id: data.id.present ? data.id.value : this.id,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      title: data.title.present ? data.title.value : this.title,
      userTitle: data.userTitle.present ? data.userTitle.value : this.userTitle,
      filename: data.filename.present ? data.filename.value : this.filename,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      itemType: data.itemType.present ? data.itemType.value : this.itemType,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      pageCount: data.pageCount.present ? data.pageCount.value : this.pageCount,
      thumbnailPath: data.thumbnailPath.present
          ? data.thumbnailPath.value
          : this.thumbnailPath,
      modifiedAt: data.modifiedAt.present
          ? data.modifiedAt.value
          : this.modifiedAt,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      unavailable: data.unavailable.present
          ? data.unavailable.value
          : this.unavailable,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Item(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('sectionId: $sectionId, ')
          ..write('title: $title, ')
          ..write('userTitle: $userTitle, ')
          ..write('filename: $filename, ')
          ..write('filePath: $filePath, ')
          ..write('relativePath: $relativePath, ')
          ..write('itemType: $itemType, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('pageCount: $pageCount, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('fileSize: $fileSize, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('unavailable: $unavailable, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    libraryId,
    sectionId,
    title,
    userTitle,
    filename,
    filePath,
    relativePath,
    itemType,
    orderIndex,
    durationSeconds,
    pageCount,
    thumbnailPath,
    modifiedAt,
    fileSize,
    fingerprint,
    unavailable,
    createdAt,
    updatedAt,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Item &&
          other.id == this.id &&
          other.libraryId == this.libraryId &&
          other.sectionId == this.sectionId &&
          other.title == this.title &&
          other.userTitle == this.userTitle &&
          other.filename == this.filename &&
          other.filePath == this.filePath &&
          other.relativePath == this.relativePath &&
          other.itemType == this.itemType &&
          other.orderIndex == this.orderIndex &&
          other.durationSeconds == this.durationSeconds &&
          other.pageCount == this.pageCount &&
          other.thumbnailPath == this.thumbnailPath &&
          other.modifiedAt == this.modifiedAt &&
          other.fileSize == this.fileSize &&
          other.fingerprint == this.fingerprint &&
          other.unavailable == this.unavailable &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.version == this.version);
}

class ItemsCompanion extends UpdateCompanion<Item> {
  final Value<String> id;
  final Value<String> libraryId;
  final Value<String> sectionId;
  final Value<String> title;
  final Value<String?> userTitle;
  final Value<String> filename;
  final Value<String> filePath;
  final Value<String> relativePath;
  final Value<String> itemType;
  final Value<int> orderIndex;
  final Value<double?> durationSeconds;
  final Value<int?> pageCount;
  final Value<String?> thumbnailPath;
  final Value<int?> modifiedAt;
  final Value<int?> fileSize;
  final Value<String?> fingerprint;
  final Value<bool> unavailable;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int> version;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.title = const Value.absent(),
    this.userTitle = const Value.absent(),
    this.filename = const Value.absent(),
    this.filePath = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.itemType = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.unavailable = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required String libraryId,
    required String sectionId,
    required String title,
    this.userTitle = const Value.absent(),
    required String filename,
    required String filePath,
    required String relativePath,
    required String itemType,
    required int orderIndex,
    this.durationSeconds = const Value.absent(),
    this.pageCount = const Value.absent(),
    this.thumbnailPath = const Value.absent(),
    this.modifiedAt = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.unavailable = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       libraryId = Value(libraryId),
       sectionId = Value(sectionId),
       title = Value(title),
       filename = Value(filename),
       filePath = Value(filePath),
       relativePath = Value(relativePath),
       itemType = Value(itemType),
       orderIndex = Value(orderIndex);
  static Insertable<Item> custom({
    Expression<String>? id,
    Expression<String>? libraryId,
    Expression<String>? sectionId,
    Expression<String>? title,
    Expression<String>? userTitle,
    Expression<String>? filename,
    Expression<String>? filePath,
    Expression<String>? relativePath,
    Expression<String>? itemType,
    Expression<int>? orderIndex,
    Expression<double>? durationSeconds,
    Expression<int>? pageCount,
    Expression<String>? thumbnailPath,
    Expression<int>? modifiedAt,
    Expression<int>? fileSize,
    Expression<String>? fingerprint,
    Expression<bool>? unavailable,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (libraryId != null) 'library_id': libraryId,
      if (sectionId != null) 'section_id': sectionId,
      if (title != null) 'title': title,
      if (userTitle != null) 'user_title': userTitle,
      if (filename != null) 'filename': filename,
      if (filePath != null) 'file_path': filePath,
      if (relativePath != null) 'relative_path': relativePath,
      if (itemType != null) 'item_type': itemType,
      if (orderIndex != null) 'order_index': orderIndex,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (pageCount != null) 'page_count': pageCount,
      if (thumbnailPath != null) 'thumbnail_path': thumbnailPath,
      if (modifiedAt != null) 'modified_at': modifiedAt,
      if (fileSize != null) 'file_size': fileSize,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (unavailable != null) 'unavailable': unavailable,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? libraryId,
    Value<String>? sectionId,
    Value<String>? title,
    Value<String?>? userTitle,
    Value<String>? filename,
    Value<String>? filePath,
    Value<String>? relativePath,
    Value<String>? itemType,
    Value<int>? orderIndex,
    Value<double?>? durationSeconds,
    Value<int?>? pageCount,
    Value<String?>? thumbnailPath,
    Value<int?>? modifiedAt,
    Value<int?>? fileSize,
    Value<String?>? fingerprint,
    Value<bool>? unavailable,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return ItemsCompanion(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      sectionId: sectionId ?? this.sectionId,
      title: title ?? this.title,
      userTitle: userTitle ?? this.userTitle,
      filename: filename ?? this.filename,
      filePath: filePath ?? this.filePath,
      relativePath: relativePath ?? this.relativePath,
      itemType: itemType ?? this.itemType,
      orderIndex: orderIndex ?? this.orderIndex,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pageCount: pageCount ?? this.pageCount,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      fileSize: fileSize ?? this.fileSize,
      fingerprint: fingerprint ?? this.fingerprint,
      unavailable: unavailable ?? this.unavailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (userTitle.present) {
      map['user_title'] = Variable<String>(userTitle.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (itemType.present) {
      map['item_type'] = Variable<String>(itemType.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<double>(durationSeconds.value);
    }
    if (pageCount.present) {
      map['page_count'] = Variable<int>(pageCount.value);
    }
    if (thumbnailPath.present) {
      map['thumbnail_path'] = Variable<String>(thumbnailPath.value);
    }
    if (modifiedAt.present) {
      map['modified_at'] = Variable<int>(modifiedAt.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (unavailable.present) {
      map['unavailable'] = Variable<bool>(unavailable.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ItemsCompanion(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('sectionId: $sectionId, ')
          ..write('title: $title, ')
          ..write('userTitle: $userTitle, ')
          ..write('filename: $filename, ')
          ..write('filePath: $filePath, ')
          ..write('relativePath: $relativePath, ')
          ..write('itemType: $itemType, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('pageCount: $pageCount, ')
          ..write('thumbnailPath: $thumbnailPath, ')
          ..write('modifiedAt: $modifiedAt, ')
          ..write('fileSize: $fileSize, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('unavailable: $unavailable, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlaybackProgressTable extends PlaybackProgress
    with TableInfo<$PlaybackProgressTable, PlaybackProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlaybackProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id)',
    ),
  );
  static const VerificationMeta _lastPositionSecondsMeta =
      const VerificationMeta('lastPositionSeconds');
  @override
  late final GeneratedColumn<double> lastPositionSeconds =
      GeneratedColumn<double>(
        'last_position_seconds',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _resumePositionSecondsMeta =
      const VerificationMeta('resumePositionSeconds');
  @override
  late final GeneratedColumn<double> resumePositionSeconds =
      GeneratedColumn<double>(
        'resume_position_seconds',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<double> durationSeconds = GeneratedColumn<double>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _percentWatchedMeta = const VerificationMeta(
    'percentWatched',
  );
  @override
  late final GeneratedColumn<double> percentWatched = GeneratedColumn<double>(
    'percent_watched',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _manualCompletionMeta = const VerificationMeta(
    'manualCompletion',
  );
  @override
  late final GeneratedColumn<bool> manualCompletion = GeneratedColumn<bool>(
    'manual_completion',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("manual_completion" IN (0, 1))',
    ),
  );
  static const VerificationMeta _playbackSpeedMeta = const VerificationMeta(
    'playbackSpeed',
  );
  @override
  late final GeneratedColumn<double> playbackSpeed = GeneratedColumn<double>(
    'playback_speed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<int> lastOpenedAt = GeneratedColumn<int>(
    'last_opened_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastEventAtMeta = const VerificationMeta(
    'lastEventAt',
  );
  @override
  late final GeneratedColumn<int> lastEventAt = GeneratedColumn<int>(
    'last_event_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    lastPositionSeconds,
    resumePositionSeconds,
    durationSeconds,
    percentWatched,
    completed,
    manualCompletion,
    playbackSpeed,
    lastOpenedAt,
    lastEventAt,
    deviceId,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'playback_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlaybackProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('last_position_seconds')) {
      context.handle(
        _lastPositionSecondsMeta,
        lastPositionSeconds.isAcceptableOrUnknown(
          data['last_position_seconds']!,
          _lastPositionSecondsMeta,
        ),
      );
    }
    if (data.containsKey('resume_position_seconds')) {
      context.handle(
        _resumePositionSecondsMeta,
        resumePositionSeconds.isAcceptableOrUnknown(
          data['resume_position_seconds']!,
          _resumePositionSecondsMeta,
        ),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('percent_watched')) {
      context.handle(
        _percentWatchedMeta,
        percentWatched.isAcceptableOrUnknown(
          data['percent_watched']!,
          _percentWatchedMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('manual_completion')) {
      context.handle(
        _manualCompletionMeta,
        manualCompletion.isAcceptableOrUnknown(
          data['manual_completion']!,
          _manualCompletionMeta,
        ),
      );
    }
    if (data.containsKey('playback_speed')) {
      context.handle(
        _playbackSpeedMeta,
        playbackSpeed.isAcceptableOrUnknown(
          data['playback_speed']!,
          _playbackSpeedMeta,
        ),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_event_at')) {
      context.handle(
        _lastEventAtMeta,
        lastEventAt.isAcceptableOrUnknown(
          data['last_event_at']!,
          _lastEventAtMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  PlaybackProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlaybackProgressData(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      lastPositionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_position_seconds'],
      )!,
      resumePositionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}resume_position_seconds'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}duration_seconds'],
      )!,
      percentWatched: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percent_watched'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      manualCompletion: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}manual_completion'],
      ),
      playbackSpeed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}playback_speed'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_opened_at'],
      )!,
      lastEventAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_event_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $PlaybackProgressTable createAlias(String alias) {
    return $PlaybackProgressTable(attachedDatabase, alias);
  }
}

class PlaybackProgressData extends DataClass
    implements Insertable<PlaybackProgressData> {
  final String itemId;
  final double lastPositionSeconds;
  final double resumePositionSeconds;
  final double durationSeconds;
  final double percentWatched;
  final bool completed;
  final bool? manualCompletion;
  final double playbackSpeed;
  final int lastOpenedAt;
  final int lastEventAt;
  final String deviceId;
  final int version;
  const PlaybackProgressData({
    required this.itemId,
    required this.lastPositionSeconds,
    required this.resumePositionSeconds,
    required this.durationSeconds,
    required this.percentWatched,
    required this.completed,
    this.manualCompletion,
    required this.playbackSpeed,
    required this.lastOpenedAt,
    required this.lastEventAt,
    required this.deviceId,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['last_position_seconds'] = Variable<double>(lastPositionSeconds);
    map['resume_position_seconds'] = Variable<double>(resumePositionSeconds);
    map['duration_seconds'] = Variable<double>(durationSeconds);
    map['percent_watched'] = Variable<double>(percentWatched);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || manualCompletion != null) {
      map['manual_completion'] = Variable<bool>(manualCompletion);
    }
    map['playback_speed'] = Variable<double>(playbackSpeed);
    map['last_opened_at'] = Variable<int>(lastOpenedAt);
    map['last_event_at'] = Variable<int>(lastEventAt);
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    return map;
  }

  PlaybackProgressCompanion toCompanion(bool nullToAbsent) {
    return PlaybackProgressCompanion(
      itemId: Value(itemId),
      lastPositionSeconds: Value(lastPositionSeconds),
      resumePositionSeconds: Value(resumePositionSeconds),
      durationSeconds: Value(durationSeconds),
      percentWatched: Value(percentWatched),
      completed: Value(completed),
      manualCompletion: manualCompletion == null && nullToAbsent
          ? const Value.absent()
          : Value(manualCompletion),
      playbackSpeed: Value(playbackSpeed),
      lastOpenedAt: Value(lastOpenedAt),
      lastEventAt: Value(lastEventAt),
      deviceId: Value(deviceId),
      version: Value(version),
    );
  }

  factory PlaybackProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlaybackProgressData(
      itemId: serializer.fromJson<String>(json['itemId']),
      lastPositionSeconds: serializer.fromJson<double>(
        json['lastPositionSeconds'],
      ),
      resumePositionSeconds: serializer.fromJson<double>(
        json['resumePositionSeconds'],
      ),
      durationSeconds: serializer.fromJson<double>(json['durationSeconds']),
      percentWatched: serializer.fromJson<double>(json['percentWatched']),
      completed: serializer.fromJson<bool>(json['completed']),
      manualCompletion: serializer.fromJson<bool?>(json['manualCompletion']),
      playbackSpeed: serializer.fromJson<double>(json['playbackSpeed']),
      lastOpenedAt: serializer.fromJson<int>(json['lastOpenedAt']),
      lastEventAt: serializer.fromJson<int>(json['lastEventAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'lastPositionSeconds': serializer.toJson<double>(lastPositionSeconds),
      'resumePositionSeconds': serializer.toJson<double>(resumePositionSeconds),
      'durationSeconds': serializer.toJson<double>(durationSeconds),
      'percentWatched': serializer.toJson<double>(percentWatched),
      'completed': serializer.toJson<bool>(completed),
      'manualCompletion': serializer.toJson<bool?>(manualCompletion),
      'playbackSpeed': serializer.toJson<double>(playbackSpeed),
      'lastOpenedAt': serializer.toJson<int>(lastOpenedAt),
      'lastEventAt': serializer.toJson<int>(lastEventAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
    };
  }

  PlaybackProgressData copyWith({
    String? itemId,
    double? lastPositionSeconds,
    double? resumePositionSeconds,
    double? durationSeconds,
    double? percentWatched,
    bool? completed,
    Value<bool?> manualCompletion = const Value.absent(),
    double? playbackSpeed,
    int? lastOpenedAt,
    int? lastEventAt,
    String? deviceId,
    int? version,
  }) => PlaybackProgressData(
    itemId: itemId ?? this.itemId,
    lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
    resumePositionSeconds: resumePositionSeconds ?? this.resumePositionSeconds,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    percentWatched: percentWatched ?? this.percentWatched,
    completed: completed ?? this.completed,
    manualCompletion: manualCompletion.present
        ? manualCompletion.value
        : this.manualCompletion,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    lastEventAt: lastEventAt ?? this.lastEventAt,
    deviceId: deviceId ?? this.deviceId,
    version: version ?? this.version,
  );
  PlaybackProgressData copyWithCompanion(PlaybackProgressCompanion data) {
    return PlaybackProgressData(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      lastPositionSeconds: data.lastPositionSeconds.present
          ? data.lastPositionSeconds.value
          : this.lastPositionSeconds,
      resumePositionSeconds: data.resumePositionSeconds.present
          ? data.resumePositionSeconds.value
          : this.resumePositionSeconds,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      percentWatched: data.percentWatched.present
          ? data.percentWatched.value
          : this.percentWatched,
      completed: data.completed.present ? data.completed.value : this.completed,
      manualCompletion: data.manualCompletion.present
          ? data.manualCompletion.value
          : this.manualCompletion,
      playbackSpeed: data.playbackSpeed.present
          ? data.playbackSpeed.value
          : this.playbackSpeed,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      lastEventAt: data.lastEventAt.present
          ? data.lastEventAt.value
          : this.lastEventAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressData(')
          ..write('itemId: $itemId, ')
          ..write('lastPositionSeconds: $lastPositionSeconds, ')
          ..write('resumePositionSeconds: $resumePositionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('percentWatched: $percentWatched, ')
          ..write('completed: $completed, ')
          ..write('manualCompletion: $manualCompletion, ')
          ..write('playbackSpeed: $playbackSpeed, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('lastEventAt: $lastEventAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    itemId,
    lastPositionSeconds,
    resumePositionSeconds,
    durationSeconds,
    percentWatched,
    completed,
    manualCompletion,
    playbackSpeed,
    lastOpenedAt,
    lastEventAt,
    deviceId,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlaybackProgressData &&
          other.itemId == this.itemId &&
          other.lastPositionSeconds == this.lastPositionSeconds &&
          other.resumePositionSeconds == this.resumePositionSeconds &&
          other.durationSeconds == this.durationSeconds &&
          other.percentWatched == this.percentWatched &&
          other.completed == this.completed &&
          other.manualCompletion == this.manualCompletion &&
          other.playbackSpeed == this.playbackSpeed &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.lastEventAt == this.lastEventAt &&
          other.deviceId == this.deviceId &&
          other.version == this.version);
}

class PlaybackProgressCompanion extends UpdateCompanion<PlaybackProgressData> {
  final Value<String> itemId;
  final Value<double> lastPositionSeconds;
  final Value<double> resumePositionSeconds;
  final Value<double> durationSeconds;
  final Value<double> percentWatched;
  final Value<bool> completed;
  final Value<bool?> manualCompletion;
  final Value<double> playbackSpeed;
  final Value<int> lastOpenedAt;
  final Value<int> lastEventAt;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<int> rowid;
  const PlaybackProgressCompanion({
    this.itemId = const Value.absent(),
    this.lastPositionSeconds = const Value.absent(),
    this.resumePositionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.percentWatched = const Value.absent(),
    this.completed = const Value.absent(),
    this.manualCompletion = const Value.absent(),
    this.playbackSpeed = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.lastEventAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlaybackProgressCompanion.insert({
    required String itemId,
    this.lastPositionSeconds = const Value.absent(),
    this.resumePositionSeconds = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.percentWatched = const Value.absent(),
    this.completed = const Value.absent(),
    this.manualCompletion = const Value.absent(),
    this.playbackSpeed = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.lastEventAt = const Value.absent(),
    required String deviceId,
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       deviceId = Value(deviceId);
  static Insertable<PlaybackProgressData> custom({
    Expression<String>? itemId,
    Expression<double>? lastPositionSeconds,
    Expression<double>? resumePositionSeconds,
    Expression<double>? durationSeconds,
    Expression<double>? percentWatched,
    Expression<bool>? completed,
    Expression<bool>? manualCompletion,
    Expression<double>? playbackSpeed,
    Expression<int>? lastOpenedAt,
    Expression<int>? lastEventAt,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (lastPositionSeconds != null)
        'last_position_seconds': lastPositionSeconds,
      if (resumePositionSeconds != null)
        'resume_position_seconds': resumePositionSeconds,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (percentWatched != null) 'percent_watched': percentWatched,
      if (completed != null) 'completed': completed,
      if (manualCompletion != null) 'manual_completion': manualCompletion,
      if (playbackSpeed != null) 'playback_speed': playbackSpeed,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (lastEventAt != null) 'last_event_at': lastEventAt,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlaybackProgressCompanion copyWith({
    Value<String>? itemId,
    Value<double>? lastPositionSeconds,
    Value<double>? resumePositionSeconds,
    Value<double>? durationSeconds,
    Value<double>? percentWatched,
    Value<bool>? completed,
    Value<bool?>? manualCompletion,
    Value<double>? playbackSpeed,
    Value<int>? lastOpenedAt,
    Value<int>? lastEventAt,
    Value<String>? deviceId,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return PlaybackProgressCompanion(
      itemId: itemId ?? this.itemId,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      resumePositionSeconds:
          resumePositionSeconds ?? this.resumePositionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      percentWatched: percentWatched ?? this.percentWatched,
      completed: completed ?? this.completed,
      manualCompletion: manualCompletion ?? this.manualCompletion,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      lastEventAt: lastEventAt ?? this.lastEventAt,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (lastPositionSeconds.present) {
      map['last_position_seconds'] = Variable<double>(
        lastPositionSeconds.value,
      );
    }
    if (resumePositionSeconds.present) {
      map['resume_position_seconds'] = Variable<double>(
        resumePositionSeconds.value,
      );
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<double>(durationSeconds.value);
    }
    if (percentWatched.present) {
      map['percent_watched'] = Variable<double>(percentWatched.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (manualCompletion.present) {
      map['manual_completion'] = Variable<bool>(manualCompletion.value);
    }
    if (playbackSpeed.present) {
      map['playback_speed'] = Variable<double>(playbackSpeed.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<int>(lastOpenedAt.value);
    }
    if (lastEventAt.present) {
      map['last_event_at'] = Variable<int>(lastEventAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlaybackProgressCompanion(')
          ..write('itemId: $itemId, ')
          ..write('lastPositionSeconds: $lastPositionSeconds, ')
          ..write('resumePositionSeconds: $resumePositionSeconds, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('percentWatched: $percentWatched, ')
          ..write('completed: $completed, ')
          ..write('manualCompletion: $manualCompletion, ')
          ..write('playbackSpeed: $playbackSpeed, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('lastEventAt: $lastEventAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingProgressTable extends ReadingProgress
    with TableInfo<$ReadingProgressTable, ReadingProgressData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingProgressTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id)',
    ),
  );
  static const VerificationMeta _lastPageMeta = const VerificationMeta(
    'lastPage',
  );
  @override
  late final GeneratedColumn<int> lastPage = GeneratedColumn<int>(
    'last_page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastScrollOffsetMeta = const VerificationMeta(
    'lastScrollOffset',
  );
  @override
  late final GeneratedColumn<double> lastScrollOffset = GeneratedColumn<double>(
    'last_scroll_offset',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _resumePageMeta = const VerificationMeta(
    'resumePage',
  );
  @override
  late final GeneratedColumn<int> resumePage = GeneratedColumn<int>(
    'resume_page',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _resumeScrollOffsetMeta =
      const VerificationMeta('resumeScrollOffset');
  @override
  late final GeneratedColumn<double> resumeScrollOffset =
      GeneratedColumn<double>(
        'resume_scroll_offset',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      );
  static const VerificationMeta _percentReadMeta = const VerificationMeta(
    'percentRead',
  );
  @override
  late final GeneratedColumn<double> percentRead = GeneratedColumn<double>(
    'percent_read',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedMeta = const VerificationMeta(
    'completed',
  );
  @override
  late final GeneratedColumn<bool> completed = GeneratedColumn<bool>(
    'completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _manualCompletionMeta = const VerificationMeta(
    'manualCompletion',
  );
  @override
  late final GeneratedColumn<bool> manualCompletion = GeneratedColumn<bool>(
    'manual_completion',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("manual_completion" IN (0, 1))',
    ),
  );
  static const VerificationMeta _zoomMeta = const VerificationMeta('zoom');
  @override
  late final GeneratedColumn<double> zoom = GeneratedColumn<double>(
    'zoom',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _readingModeMeta = const VerificationMeta(
    'readingMode',
  );
  @override
  late final GeneratedColumn<String> readingMode = GeneratedColumn<String>(
    'reading_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('fitWidth'),
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<int> lastOpenedAt = GeneratedColumn<int>(
    'last_opened_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastEventAtMeta = const VerificationMeta(
    'lastEventAt',
  );
  @override
  late final GeneratedColumn<int> lastEventAt = GeneratedColumn<int>(
    'last_event_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemId,
    lastPage,
    lastScrollOffset,
    resumePage,
    resumeScrollOffset,
    percentRead,
    completed,
    manualCompletion,
    zoom,
    readingMode,
    lastOpenedAt,
    lastEventAt,
    deviceId,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReadingProgressData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('last_page')) {
      context.handle(
        _lastPageMeta,
        lastPage.isAcceptableOrUnknown(data['last_page']!, _lastPageMeta),
      );
    }
    if (data.containsKey('last_scroll_offset')) {
      context.handle(
        _lastScrollOffsetMeta,
        lastScrollOffset.isAcceptableOrUnknown(
          data['last_scroll_offset']!,
          _lastScrollOffsetMeta,
        ),
      );
    }
    if (data.containsKey('resume_page')) {
      context.handle(
        _resumePageMeta,
        resumePage.isAcceptableOrUnknown(data['resume_page']!, _resumePageMeta),
      );
    }
    if (data.containsKey('resume_scroll_offset')) {
      context.handle(
        _resumeScrollOffsetMeta,
        resumeScrollOffset.isAcceptableOrUnknown(
          data['resume_scroll_offset']!,
          _resumeScrollOffsetMeta,
        ),
      );
    }
    if (data.containsKey('percent_read')) {
      context.handle(
        _percentReadMeta,
        percentRead.isAcceptableOrUnknown(
          data['percent_read']!,
          _percentReadMeta,
        ),
      );
    }
    if (data.containsKey('completed')) {
      context.handle(
        _completedMeta,
        completed.isAcceptableOrUnknown(data['completed']!, _completedMeta),
      );
    }
    if (data.containsKey('manual_completion')) {
      context.handle(
        _manualCompletionMeta,
        manualCompletion.isAcceptableOrUnknown(
          data['manual_completion']!,
          _manualCompletionMeta,
        ),
      );
    }
    if (data.containsKey('zoom')) {
      context.handle(
        _zoomMeta,
        zoom.isAcceptableOrUnknown(data['zoom']!, _zoomMeta),
      );
    }
    if (data.containsKey('reading_mode')) {
      context.handle(
        _readingModeMeta,
        readingMode.isAcceptableOrUnknown(
          data['reading_mode']!,
          _readingModeMeta,
        ),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('last_event_at')) {
      context.handle(
        _lastEventAtMeta,
        lastEventAt.isAcceptableOrUnknown(
          data['last_event_at']!,
          _lastEventAtMeta,
        ),
      );
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  ReadingProgressData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingProgressData(
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      lastPage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_page'],
      )!,
      lastScrollOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_scroll_offset'],
      )!,
      resumePage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}resume_page'],
      )!,
      resumeScrollOffset: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}resume_scroll_offset'],
      )!,
      percentRead: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}percent_read'],
      )!,
      completed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}completed'],
      )!,
      manualCompletion: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}manual_completion'],
      ),
      zoom: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}zoom'],
      )!,
      readingMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reading_mode'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_opened_at'],
      )!,
      lastEventAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_event_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $ReadingProgressTable createAlias(String alias) {
    return $ReadingProgressTable(attachedDatabase, alias);
  }
}

class ReadingProgressData extends DataClass
    implements Insertable<ReadingProgressData> {
  final String itemId;
  final int lastPage;
  final double lastScrollOffset;
  final int resumePage;
  final double resumeScrollOffset;
  final double percentRead;
  final bool completed;
  final bool? manualCompletion;
  final double zoom;
  final String readingMode;
  final int lastOpenedAt;
  final int lastEventAt;
  final String deviceId;
  final int version;
  const ReadingProgressData({
    required this.itemId,
    required this.lastPage,
    required this.lastScrollOffset,
    required this.resumePage,
    required this.resumeScrollOffset,
    required this.percentRead,
    required this.completed,
    this.manualCompletion,
    required this.zoom,
    required this.readingMode,
    required this.lastOpenedAt,
    required this.lastEventAt,
    required this.deviceId,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['last_page'] = Variable<int>(lastPage);
    map['last_scroll_offset'] = Variable<double>(lastScrollOffset);
    map['resume_page'] = Variable<int>(resumePage);
    map['resume_scroll_offset'] = Variable<double>(resumeScrollOffset);
    map['percent_read'] = Variable<double>(percentRead);
    map['completed'] = Variable<bool>(completed);
    if (!nullToAbsent || manualCompletion != null) {
      map['manual_completion'] = Variable<bool>(manualCompletion);
    }
    map['zoom'] = Variable<double>(zoom);
    map['reading_mode'] = Variable<String>(readingMode);
    map['last_opened_at'] = Variable<int>(lastOpenedAt);
    map['last_event_at'] = Variable<int>(lastEventAt);
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    return map;
  }

  ReadingProgressCompanion toCompanion(bool nullToAbsent) {
    return ReadingProgressCompanion(
      itemId: Value(itemId),
      lastPage: Value(lastPage),
      lastScrollOffset: Value(lastScrollOffset),
      resumePage: Value(resumePage),
      resumeScrollOffset: Value(resumeScrollOffset),
      percentRead: Value(percentRead),
      completed: Value(completed),
      manualCompletion: manualCompletion == null && nullToAbsent
          ? const Value.absent()
          : Value(manualCompletion),
      zoom: Value(zoom),
      readingMode: Value(readingMode),
      lastOpenedAt: Value(lastOpenedAt),
      lastEventAt: Value(lastEventAt),
      deviceId: Value(deviceId),
      version: Value(version),
    );
  }

  factory ReadingProgressData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingProgressData(
      itemId: serializer.fromJson<String>(json['itemId']),
      lastPage: serializer.fromJson<int>(json['lastPage']),
      lastScrollOffset: serializer.fromJson<double>(json['lastScrollOffset']),
      resumePage: serializer.fromJson<int>(json['resumePage']),
      resumeScrollOffset: serializer.fromJson<double>(
        json['resumeScrollOffset'],
      ),
      percentRead: serializer.fromJson<double>(json['percentRead']),
      completed: serializer.fromJson<bool>(json['completed']),
      manualCompletion: serializer.fromJson<bool?>(json['manualCompletion']),
      zoom: serializer.fromJson<double>(json['zoom']),
      readingMode: serializer.fromJson<String>(json['readingMode']),
      lastOpenedAt: serializer.fromJson<int>(json['lastOpenedAt']),
      lastEventAt: serializer.fromJson<int>(json['lastEventAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'lastPage': serializer.toJson<int>(lastPage),
      'lastScrollOffset': serializer.toJson<double>(lastScrollOffset),
      'resumePage': serializer.toJson<int>(resumePage),
      'resumeScrollOffset': serializer.toJson<double>(resumeScrollOffset),
      'percentRead': serializer.toJson<double>(percentRead),
      'completed': serializer.toJson<bool>(completed),
      'manualCompletion': serializer.toJson<bool?>(manualCompletion),
      'zoom': serializer.toJson<double>(zoom),
      'readingMode': serializer.toJson<String>(readingMode),
      'lastOpenedAt': serializer.toJson<int>(lastOpenedAt),
      'lastEventAt': serializer.toJson<int>(lastEventAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
    };
  }

  ReadingProgressData copyWith({
    String? itemId,
    int? lastPage,
    double? lastScrollOffset,
    int? resumePage,
    double? resumeScrollOffset,
    double? percentRead,
    bool? completed,
    Value<bool?> manualCompletion = const Value.absent(),
    double? zoom,
    String? readingMode,
    int? lastOpenedAt,
    int? lastEventAt,
    String? deviceId,
    int? version,
  }) => ReadingProgressData(
    itemId: itemId ?? this.itemId,
    lastPage: lastPage ?? this.lastPage,
    lastScrollOffset: lastScrollOffset ?? this.lastScrollOffset,
    resumePage: resumePage ?? this.resumePage,
    resumeScrollOffset: resumeScrollOffset ?? this.resumeScrollOffset,
    percentRead: percentRead ?? this.percentRead,
    completed: completed ?? this.completed,
    manualCompletion: manualCompletion.present
        ? manualCompletion.value
        : this.manualCompletion,
    zoom: zoom ?? this.zoom,
    readingMode: readingMode ?? this.readingMode,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    lastEventAt: lastEventAt ?? this.lastEventAt,
    deviceId: deviceId ?? this.deviceId,
    version: version ?? this.version,
  );
  ReadingProgressData copyWithCompanion(ReadingProgressCompanion data) {
    return ReadingProgressData(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      lastPage: data.lastPage.present ? data.lastPage.value : this.lastPage,
      lastScrollOffset: data.lastScrollOffset.present
          ? data.lastScrollOffset.value
          : this.lastScrollOffset,
      resumePage: data.resumePage.present
          ? data.resumePage.value
          : this.resumePage,
      resumeScrollOffset: data.resumeScrollOffset.present
          ? data.resumeScrollOffset.value
          : this.resumeScrollOffset,
      percentRead: data.percentRead.present
          ? data.percentRead.value
          : this.percentRead,
      completed: data.completed.present ? data.completed.value : this.completed,
      manualCompletion: data.manualCompletion.present
          ? data.manualCompletion.value
          : this.manualCompletion,
      zoom: data.zoom.present ? data.zoom.value : this.zoom,
      readingMode: data.readingMode.present
          ? data.readingMode.value
          : this.readingMode,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      lastEventAt: data.lastEventAt.present
          ? data.lastEventAt.value
          : this.lastEventAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressData(')
          ..write('itemId: $itemId, ')
          ..write('lastPage: $lastPage, ')
          ..write('lastScrollOffset: $lastScrollOffset, ')
          ..write('resumePage: $resumePage, ')
          ..write('resumeScrollOffset: $resumeScrollOffset, ')
          ..write('percentRead: $percentRead, ')
          ..write('completed: $completed, ')
          ..write('manualCompletion: $manualCompletion, ')
          ..write('zoom: $zoom, ')
          ..write('readingMode: $readingMode, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('lastEventAt: $lastEventAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    itemId,
    lastPage,
    lastScrollOffset,
    resumePage,
    resumeScrollOffset,
    percentRead,
    completed,
    manualCompletion,
    zoom,
    readingMode,
    lastOpenedAt,
    lastEventAt,
    deviceId,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingProgressData &&
          other.itemId == this.itemId &&
          other.lastPage == this.lastPage &&
          other.lastScrollOffset == this.lastScrollOffset &&
          other.resumePage == this.resumePage &&
          other.resumeScrollOffset == this.resumeScrollOffset &&
          other.percentRead == this.percentRead &&
          other.completed == this.completed &&
          other.manualCompletion == this.manualCompletion &&
          other.zoom == this.zoom &&
          other.readingMode == this.readingMode &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.lastEventAt == this.lastEventAt &&
          other.deviceId == this.deviceId &&
          other.version == this.version);
}

class ReadingProgressCompanion extends UpdateCompanion<ReadingProgressData> {
  final Value<String> itemId;
  final Value<int> lastPage;
  final Value<double> lastScrollOffset;
  final Value<int> resumePage;
  final Value<double> resumeScrollOffset;
  final Value<double> percentRead;
  final Value<bool> completed;
  final Value<bool?> manualCompletion;
  final Value<double> zoom;
  final Value<String> readingMode;
  final Value<int> lastOpenedAt;
  final Value<int> lastEventAt;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<int> rowid;
  const ReadingProgressCompanion({
    this.itemId = const Value.absent(),
    this.lastPage = const Value.absent(),
    this.lastScrollOffset = const Value.absent(),
    this.resumePage = const Value.absent(),
    this.resumeScrollOffset = const Value.absent(),
    this.percentRead = const Value.absent(),
    this.completed = const Value.absent(),
    this.manualCompletion = const Value.absent(),
    this.zoom = const Value.absent(),
    this.readingMode = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.lastEventAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReadingProgressCompanion.insert({
    required String itemId,
    this.lastPage = const Value.absent(),
    this.lastScrollOffset = const Value.absent(),
    this.resumePage = const Value.absent(),
    this.resumeScrollOffset = const Value.absent(),
    this.percentRead = const Value.absent(),
    this.completed = const Value.absent(),
    this.manualCompletion = const Value.absent(),
    this.zoom = const Value.absent(),
    this.readingMode = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.lastEventAt = const Value.absent(),
    required String deviceId,
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       deviceId = Value(deviceId);
  static Insertable<ReadingProgressData> custom({
    Expression<String>? itemId,
    Expression<int>? lastPage,
    Expression<double>? lastScrollOffset,
    Expression<int>? resumePage,
    Expression<double>? resumeScrollOffset,
    Expression<double>? percentRead,
    Expression<bool>? completed,
    Expression<bool>? manualCompletion,
    Expression<double>? zoom,
    Expression<String>? readingMode,
    Expression<int>? lastOpenedAt,
    Expression<int>? lastEventAt,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (lastPage != null) 'last_page': lastPage,
      if (lastScrollOffset != null) 'last_scroll_offset': lastScrollOffset,
      if (resumePage != null) 'resume_page': resumePage,
      if (resumeScrollOffset != null)
        'resume_scroll_offset': resumeScrollOffset,
      if (percentRead != null) 'percent_read': percentRead,
      if (completed != null) 'completed': completed,
      if (manualCompletion != null) 'manual_completion': manualCompletion,
      if (zoom != null) 'zoom': zoom,
      if (readingMode != null) 'reading_mode': readingMode,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (lastEventAt != null) 'last_event_at': lastEventAt,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReadingProgressCompanion copyWith({
    Value<String>? itemId,
    Value<int>? lastPage,
    Value<double>? lastScrollOffset,
    Value<int>? resumePage,
    Value<double>? resumeScrollOffset,
    Value<double>? percentRead,
    Value<bool>? completed,
    Value<bool?>? manualCompletion,
    Value<double>? zoom,
    Value<String>? readingMode,
    Value<int>? lastOpenedAt,
    Value<int>? lastEventAt,
    Value<String>? deviceId,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return ReadingProgressCompanion(
      itemId: itemId ?? this.itemId,
      lastPage: lastPage ?? this.lastPage,
      lastScrollOffset: lastScrollOffset ?? this.lastScrollOffset,
      resumePage: resumePage ?? this.resumePage,
      resumeScrollOffset: resumeScrollOffset ?? this.resumeScrollOffset,
      percentRead: percentRead ?? this.percentRead,
      completed: completed ?? this.completed,
      manualCompletion: manualCompletion ?? this.manualCompletion,
      zoom: zoom ?? this.zoom,
      readingMode: readingMode ?? this.readingMode,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      lastEventAt: lastEventAt ?? this.lastEventAt,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (lastPage.present) {
      map['last_page'] = Variable<int>(lastPage.value);
    }
    if (lastScrollOffset.present) {
      map['last_scroll_offset'] = Variable<double>(lastScrollOffset.value);
    }
    if (resumePage.present) {
      map['resume_page'] = Variable<int>(resumePage.value);
    }
    if (resumeScrollOffset.present) {
      map['resume_scroll_offset'] = Variable<double>(resumeScrollOffset.value);
    }
    if (percentRead.present) {
      map['percent_read'] = Variable<double>(percentRead.value);
    }
    if (completed.present) {
      map['completed'] = Variable<bool>(completed.value);
    }
    if (manualCompletion.present) {
      map['manual_completion'] = Variable<bool>(manualCompletion.value);
    }
    if (zoom.present) {
      map['zoom'] = Variable<double>(zoom.value);
    }
    if (readingMode.present) {
      map['reading_mode'] = Variable<String>(readingMode.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<int>(lastOpenedAt.value);
    }
    if (lastEventAt.present) {
      map['last_event_at'] = Variable<int>(lastEventAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingProgressCompanion(')
          ..write('itemId: $itemId, ')
          ..write('lastPage: $lastPage, ')
          ..write('lastScrollOffset: $lastScrollOffset, ')
          ..write('resumePage: $resumePage, ')
          ..write('resumeScrollOffset: $resumeScrollOffset, ')
          ..write('percentRead: $percentRead, ')
          ..write('completed: $completed, ')
          ..write('manualCompletion: $manualCompletion, ')
          ..write('zoom: $zoom, ')
          ..write('readingMode: $readingMode, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('lastEventAt: $lastEventAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryIdMeta = const VerificationMeta(
    'libraryId',
  );
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
    'library_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES libraries (id)',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id)',
    ),
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionSecondsMeta = const VerificationMeta(
    'positionSeconds',
  );
  @override
  late final GeneratedColumn<double> positionSeconds = GeneratedColumn<double>(
    'position_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    libraryId,
    itemId,
    content,
    positionSeconds,
    pageNumber,
    createdAt,
    updatedAt,
    deviceId,
    version,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('library_id')) {
      context.handle(
        _libraryIdMeta,
        libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_libraryIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
        _positionSecondsMeta,
        positionSeconds.isAcceptableOrUnknown(
          data['position_seconds']!,
          _positionSecondsMeta,
        ),
      );
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      libraryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      positionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_seconds'],
      ),
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final String id;
  final String libraryId;
  final String? itemId;
  final String content;
  final double? positionSeconds;
  final int? pageNumber;
  final int createdAt;
  final int updatedAt;
  final String deviceId;
  final int version;
  final bool deleted;
  const Note({
    required this.id,
    required this.libraryId,
    this.itemId,
    required this.content,
    this.positionSeconds,
    this.pageNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.deviceId,
    required this.version,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['library_id'] = Variable<String>(libraryId);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || positionSeconds != null) {
      map['position_seconds'] = Variable<double>(positionSeconds);
    }
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<int>(pageNumber);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      libraryId: Value(libraryId),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      content: Value(content),
      positionSeconds: positionSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(positionSeconds),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      version: Value(version),
      deleted: Value(deleted),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<String>(json['id']),
      libraryId: serializer.fromJson<String>(json['libraryId']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      content: serializer.fromJson<String>(json['content']),
      positionSeconds: serializer.fromJson<double?>(json['positionSeconds']),
      pageNumber: serializer.fromJson<int?>(json['pageNumber']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      version: serializer.fromJson<int>(json['version']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'libraryId': serializer.toJson<String>(libraryId),
      'itemId': serializer.toJson<String?>(itemId),
      'content': serializer.toJson<String>(content),
      'positionSeconds': serializer.toJson<double?>(positionSeconds),
      'pageNumber': serializer.toJson<int?>(pageNumber),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Note copyWith({
    String? id,
    String? libraryId,
    Value<String?> itemId = const Value.absent(),
    String? content,
    Value<double?> positionSeconds = const Value.absent(),
    Value<int?> pageNumber = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    String? deviceId,
    int? version,
    bool? deleted,
  }) => Note(
    id: id ?? this.id,
    libraryId: libraryId ?? this.libraryId,
    itemId: itemId.present ? itemId.value : this.itemId,
    content: content ?? this.content,
    positionSeconds: positionSeconds.present
        ? positionSeconds.value
        : this.positionSeconds,
    pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    version: version ?? this.version,
    deleted: deleted ?? this.deleted,
  );
  Note copyWithCompanion(NotesCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      content: data.content.present ? data.content.value : this.content,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('itemId: $itemId, ')
          ..write('content: $content, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    libraryId,
    itemId,
    content,
    positionSeconds,
    pageNumber,
    createdAt,
    updatedAt,
    deviceId,
    version,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.libraryId == this.libraryId &&
          other.itemId == this.itemId &&
          other.content == this.content &&
          other.positionSeconds == this.positionSeconds &&
          other.pageNumber == this.pageNumber &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.version == this.version &&
          other.deleted == this.deleted);
}

class NotesCompanion extends UpdateCompanion<Note> {
  final Value<String> id;
  final Value<String> libraryId;
  final Value<String?> itemId;
  final Value<String> content;
  final Value<double?> positionSeconds;
  final Value<int?> pageNumber;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<bool> deleted;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.content = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    required String libraryId,
    this.itemId = const Value.absent(),
    required String content,
    this.positionSeconds = const Value.absent(),
    this.pageNumber = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    required String deviceId,
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       libraryId = Value(libraryId),
       content = Value(content),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<Note> custom({
    Expression<String>? id,
    Expression<String>? libraryId,
    Expression<String>? itemId,
    Expression<String>? content,
    Expression<double>? positionSeconds,
    Expression<int>? pageNumber,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (libraryId != null) 'library_id': libraryId,
      if (itemId != null) 'item_id': itemId,
      if (content != null) 'content': content,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (pageNumber != null) 'page_number': pageNumber,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? libraryId,
    Value<String?>? itemId,
    Value<String>? content,
    Value<double?>? positionSeconds,
    Value<int?>? pageNumber,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int>? version,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      itemId: itemId ?? this.itemId,
      content: content ?? this.content,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      pageNumber: pageNumber ?? this.pageNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<double>(positionSeconds.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('itemId: $itemId, ')
          ..write('content: $content, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarksTable extends Bookmarks
    with TableInfo<$BookmarksTable, Bookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libraryIdMeta = const VerificationMeta(
    'libraryId',
  );
  @override
  late final GeneratedColumn<String> libraryId = GeneratedColumn<String>(
    'library_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES libraries (id)',
    ),
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES items (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionSecondsMeta = const VerificationMeta(
    'positionSeconds',
  );
  @override
  late final GeneratedColumn<double> positionSeconds = GeneratedColumn<double>(
    'position_seconds',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pageNumberMeta = const VerificationMeta(
    'pageNumber',
  );
  @override
  late final GeneratedColumn<int> pageNumber = GeneratedColumn<int>(
    'page_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    libraryId,
    itemId,
    title,
    description,
    positionSeconds,
    pageNumber,
    createdAt,
    updatedAt,
    deviceId,
    version,
    deleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmarks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Bookmark> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('library_id')) {
      context.handle(
        _libraryIdMeta,
        libraryId.isAcceptableOrUnknown(data['library_id']!, _libraryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_libraryIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('position_seconds')) {
      context.handle(
        _positionSecondsMeta,
        positionSeconds.isAcceptableOrUnknown(
          data['position_seconds']!,
          _positionSecondsMeta,
        ),
      );
    }
    if (data.containsKey('page_number')) {
      context.handle(
        _pageNumberMeta,
        pageNumber.isAcceptableOrUnknown(data['page_number']!, _pageNumberMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Bookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Bookmark(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      libraryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}library_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      positionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}position_seconds'],
      ),
      pageNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}page_number'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
    );
  }

  @override
  $BookmarksTable createAlias(String alias) {
    return $BookmarksTable(attachedDatabase, alias);
  }
}

class Bookmark extends DataClass implements Insertable<Bookmark> {
  final String id;
  final String libraryId;
  final String itemId;
  final String title;
  final String? description;
  final double? positionSeconds;
  final int? pageNumber;
  final int createdAt;
  final int updatedAt;
  final String deviceId;
  final int version;
  final bool deleted;
  const Bookmark({
    required this.id,
    required this.libraryId,
    required this.itemId,
    required this.title,
    this.description,
    this.positionSeconds,
    this.pageNumber,
    required this.createdAt,
    required this.updatedAt,
    required this.deviceId,
    required this.version,
    required this.deleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['library_id'] = Variable<String>(libraryId);
    map['item_id'] = Variable<String>(itemId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || positionSeconds != null) {
      map['position_seconds'] = Variable<double>(positionSeconds);
    }
    if (!nullToAbsent || pageNumber != null) {
      map['page_number'] = Variable<int>(pageNumber);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    map['device_id'] = Variable<String>(deviceId);
    map['version'] = Variable<int>(version);
    map['deleted'] = Variable<bool>(deleted);
    return map;
  }

  BookmarksCompanion toCompanion(bool nullToAbsent) {
    return BookmarksCompanion(
      id: Value(id),
      libraryId: Value(libraryId),
      itemId: Value(itemId),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      positionSeconds: positionSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(positionSeconds),
      pageNumber: pageNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(pageNumber),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deviceId: Value(deviceId),
      version: Value(version),
      deleted: Value(deleted),
    );
  }

  factory Bookmark.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Bookmark(
      id: serializer.fromJson<String>(json['id']),
      libraryId: serializer.fromJson<String>(json['libraryId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      positionSeconds: serializer.fromJson<double?>(json['positionSeconds']),
      pageNumber: serializer.fromJson<int?>(json['pageNumber']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      version: serializer.fromJson<int>(json['version']),
      deleted: serializer.fromJson<bool>(json['deleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'libraryId': serializer.toJson<String>(libraryId),
      'itemId': serializer.toJson<String>(itemId),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'positionSeconds': serializer.toJson<double?>(positionSeconds),
      'pageNumber': serializer.toJson<int?>(pageNumber),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'deviceId': serializer.toJson<String>(deviceId),
      'version': serializer.toJson<int>(version),
      'deleted': serializer.toJson<bool>(deleted),
    };
  }

  Bookmark copyWith({
    String? id,
    String? libraryId,
    String? itemId,
    String? title,
    Value<String?> description = const Value.absent(),
    Value<double?> positionSeconds = const Value.absent(),
    Value<int?> pageNumber = const Value.absent(),
    int? createdAt,
    int? updatedAt,
    String? deviceId,
    int? version,
    bool? deleted,
  }) => Bookmark(
    id: id ?? this.id,
    libraryId: libraryId ?? this.libraryId,
    itemId: itemId ?? this.itemId,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    positionSeconds: positionSeconds.present
        ? positionSeconds.value
        : this.positionSeconds,
    pageNumber: pageNumber.present ? pageNumber.value : this.pageNumber,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deviceId: deviceId ?? this.deviceId,
    version: version ?? this.version,
    deleted: deleted ?? this.deleted,
  );
  Bookmark copyWithCompanion(BookmarksCompanion data) {
    return Bookmark(
      id: data.id.present ? data.id.value : this.id,
      libraryId: data.libraryId.present ? data.libraryId.value : this.libraryId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      positionSeconds: data.positionSeconds.present
          ? data.positionSeconds.value
          : this.positionSeconds,
      pageNumber: data.pageNumber.present
          ? data.pageNumber.value
          : this.pageNumber,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      version: data.version.present ? data.version.value : this.version,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Bookmark(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('itemId: $itemId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    libraryId,
    itemId,
    title,
    description,
    positionSeconds,
    pageNumber,
    createdAt,
    updatedAt,
    deviceId,
    version,
    deleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Bookmark &&
          other.id == this.id &&
          other.libraryId == this.libraryId &&
          other.itemId == this.itemId &&
          other.title == this.title &&
          other.description == this.description &&
          other.positionSeconds == this.positionSeconds &&
          other.pageNumber == this.pageNumber &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deviceId == this.deviceId &&
          other.version == this.version &&
          other.deleted == this.deleted);
}

class BookmarksCompanion extends UpdateCompanion<Bookmark> {
  final Value<String> id;
  final Value<String> libraryId;
  final Value<String> itemId;
  final Value<String> title;
  final Value<String?> description;
  final Value<double?> positionSeconds;
  final Value<int?> pageNumber;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String> deviceId;
  final Value<int> version;
  final Value<bool> deleted;
  final Value<int> rowid;
  const BookmarksCompanion({
    this.id = const Value.absent(),
    this.libraryId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.pageNumber = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarksCompanion.insert({
    required String id,
    required String libraryId,
    required String itemId,
    required String title,
    this.description = const Value.absent(),
    this.positionSeconds = const Value.absent(),
    this.pageNumber = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    required String deviceId,
    this.version = const Value.absent(),
    this.deleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       libraryId = Value(libraryId),
       itemId = Value(itemId),
       title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       deviceId = Value(deviceId);
  static Insertable<Bookmark> custom({
    Expression<String>? id,
    Expression<String>? libraryId,
    Expression<String>? itemId,
    Expression<String>? title,
    Expression<String>? description,
    Expression<double>? positionSeconds,
    Expression<int>? pageNumber,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? deviceId,
    Expression<int>? version,
    Expression<bool>? deleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (libraryId != null) 'library_id': libraryId,
      if (itemId != null) 'item_id': itemId,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (positionSeconds != null) 'position_seconds': positionSeconds,
      if (pageNumber != null) 'page_number': pageNumber,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deviceId != null) 'device_id': deviceId,
      if (version != null) 'version': version,
      if (deleted != null) 'deleted': deleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarksCompanion copyWith({
    Value<String>? id,
    Value<String>? libraryId,
    Value<String>? itemId,
    Value<String>? title,
    Value<String?>? description,
    Value<double?>? positionSeconds,
    Value<int?>? pageNumber,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String>? deviceId,
    Value<int>? version,
    Value<bool>? deleted,
    Value<int>? rowid,
  }) {
    return BookmarksCompanion(
      id: id ?? this.id,
      libraryId: libraryId ?? this.libraryId,
      itemId: itemId ?? this.itemId,
      title: title ?? this.title,
      description: description ?? this.description,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      pageNumber: pageNumber ?? this.pageNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      deleted: deleted ?? this.deleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (libraryId.present) {
      map['library_id'] = Variable<String>(libraryId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (positionSeconds.present) {
      map['position_seconds'] = Variable<double>(positionSeconds.value);
    }
    if (pageNumber.present) {
      map['page_number'] = Variable<int>(pageNumber.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarksCompanion(')
          ..write('id: $id, ')
          ..write('libraryId: $libraryId, ')
          ..write('itemId: $itemId, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('positionSeconds: $positionSeconds, ')
          ..write('pageNumber: $pageNumber, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deviceId: $deviceId, ')
          ..write('version: $version, ')
          ..write('deleted: $deleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KnownDevicesTable extends KnownDevices
    with TableInfo<$KnownDevicesTable, KnownDevice> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KnownDevicesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenHashMeta = const VerificationMeta(
    'tokenHash',
  );
  @override
  late final GeneratedColumn<String> tokenHash = GeneratedColumn<String>(
    'token_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _approvedMeta = const VerificationMeta(
    'approved',
  );
  @override
  late final GeneratedColumn<bool> approved = GeneratedColumn<bool>(
    'approved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("approved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenAtMeta = const VerificationMeta(
    'lastSeenAt',
  );
  @override
  late final GeneratedColumn<int> lastSeenAt = GeneratedColumn<int>(
    'last_seen_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastSyncAtMeta = const VerificationMeta(
    'lastSyncAt',
  );
  @override
  late final GeneratedColumn<int> lastSyncAt = GeneratedColumn<int>(
    'last_sync_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastAddressMeta = const VerificationMeta(
    'lastAddress',
  );
  @override
  late final GeneratedColumn<String> lastAddress = GeneratedColumn<String>(
    'last_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revokedMeta = const VerificationMeta(
    'revoked',
  );
  @override
  late final GeneratedColumn<bool> revoked = GeneratedColumn<bool>(
    'revoked',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("revoked" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    tokenHash,
    approved,
    createdAt,
    lastSeenAt,
    lastSyncAt,
    lastAddress,
    revoked,
    version,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'known_devices';
  @override
  VerificationContext validateIntegrity(
    Insertable<KnownDevice> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('token_hash')) {
      context.handle(
        _tokenHashMeta,
        tokenHash.isAcceptableOrUnknown(data['token_hash']!, _tokenHashMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenHashMeta);
    }
    if (data.containsKey('approved')) {
      context.handle(
        _approvedMeta,
        approved.isAcceptableOrUnknown(data['approved']!, _approvedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_seen_at')) {
      context.handle(
        _lastSeenAtMeta,
        lastSeenAt.isAcceptableOrUnknown(
          data['last_seen_at']!,
          _lastSeenAtMeta,
        ),
      );
    }
    if (data.containsKey('last_sync_at')) {
      context.handle(
        _lastSyncAtMeta,
        lastSyncAt.isAcceptableOrUnknown(
          data['last_sync_at']!,
          _lastSyncAtMeta,
        ),
      );
    }
    if (data.containsKey('last_address')) {
      context.handle(
        _lastAddressMeta,
        lastAddress.isAcceptableOrUnknown(
          data['last_address']!,
          _lastAddressMeta,
        ),
      );
    }
    if (data.containsKey('revoked')) {
      context.handle(
        _revokedMeta,
        revoked.isAcceptableOrUnknown(data['revoked']!, _revokedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KnownDevice map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KnownDevice(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      tokenHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token_hash'],
      )!,
      approved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}approved'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      lastSeenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen_at'],
      ),
      lastSyncAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sync_at'],
      ),
      lastAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_address'],
      ),
      revoked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}revoked'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
    );
  }

  @override
  $KnownDevicesTable createAlias(String alias) {
    return $KnownDevicesTable(attachedDatabase, alias);
  }
}

class KnownDevice extends DataClass implements Insertable<KnownDevice> {
  final String id;
  final String name;
  final String tokenHash;
  final bool approved;
  final int createdAt;
  final int? lastSeenAt;
  final int? lastSyncAt;
  final String? lastAddress;
  final bool revoked;
  final int version;
  const KnownDevice({
    required this.id,
    required this.name,
    required this.tokenHash,
    required this.approved,
    required this.createdAt,
    this.lastSeenAt,
    this.lastSyncAt,
    this.lastAddress,
    required this.revoked,
    required this.version,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['token_hash'] = Variable<String>(tokenHash);
    map['approved'] = Variable<bool>(approved);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || lastSeenAt != null) {
      map['last_seen_at'] = Variable<int>(lastSeenAt);
    }
    if (!nullToAbsent || lastSyncAt != null) {
      map['last_sync_at'] = Variable<int>(lastSyncAt);
    }
    if (!nullToAbsent || lastAddress != null) {
      map['last_address'] = Variable<String>(lastAddress);
    }
    map['revoked'] = Variable<bool>(revoked);
    map['version'] = Variable<int>(version);
    return map;
  }

  KnownDevicesCompanion toCompanion(bool nullToAbsent) {
    return KnownDevicesCompanion(
      id: Value(id),
      name: Value(name),
      tokenHash: Value(tokenHash),
      approved: Value(approved),
      createdAt: Value(createdAt),
      lastSeenAt: lastSeenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeenAt),
      lastSyncAt: lastSyncAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncAt),
      lastAddress: lastAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAddress),
      revoked: Value(revoked),
      version: Value(version),
    );
  }

  factory KnownDevice.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KnownDevice(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      tokenHash: serializer.fromJson<String>(json['tokenHash']),
      approved: serializer.fromJson<bool>(json['approved']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      lastSeenAt: serializer.fromJson<int?>(json['lastSeenAt']),
      lastSyncAt: serializer.fromJson<int?>(json['lastSyncAt']),
      lastAddress: serializer.fromJson<String?>(json['lastAddress']),
      revoked: serializer.fromJson<bool>(json['revoked']),
      version: serializer.fromJson<int>(json['version']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'tokenHash': serializer.toJson<String>(tokenHash),
      'approved': serializer.toJson<bool>(approved),
      'createdAt': serializer.toJson<int>(createdAt),
      'lastSeenAt': serializer.toJson<int?>(lastSeenAt),
      'lastSyncAt': serializer.toJson<int?>(lastSyncAt),
      'lastAddress': serializer.toJson<String?>(lastAddress),
      'revoked': serializer.toJson<bool>(revoked),
      'version': serializer.toJson<int>(version),
    };
  }

  KnownDevice copyWith({
    String? id,
    String? name,
    String? tokenHash,
    bool? approved,
    int? createdAt,
    Value<int?> lastSeenAt = const Value.absent(),
    Value<int?> lastSyncAt = const Value.absent(),
    Value<String?> lastAddress = const Value.absent(),
    bool? revoked,
    int? version,
  }) => KnownDevice(
    id: id ?? this.id,
    name: name ?? this.name,
    tokenHash: tokenHash ?? this.tokenHash,
    approved: approved ?? this.approved,
    createdAt: createdAt ?? this.createdAt,
    lastSeenAt: lastSeenAt.present ? lastSeenAt.value : this.lastSeenAt,
    lastSyncAt: lastSyncAt.present ? lastSyncAt.value : this.lastSyncAt,
    lastAddress: lastAddress.present ? lastAddress.value : this.lastAddress,
    revoked: revoked ?? this.revoked,
    version: version ?? this.version,
  );
  KnownDevice copyWithCompanion(KnownDevicesCompanion data) {
    return KnownDevice(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      tokenHash: data.tokenHash.present ? data.tokenHash.value : this.tokenHash,
      approved: data.approved.present ? data.approved.value : this.approved,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastSeenAt: data.lastSeenAt.present
          ? data.lastSeenAt.value
          : this.lastSeenAt,
      lastSyncAt: data.lastSyncAt.present
          ? data.lastSyncAt.value
          : this.lastSyncAt,
      lastAddress: data.lastAddress.present
          ? data.lastAddress.value
          : this.lastAddress,
      revoked: data.revoked.present ? data.revoked.value : this.revoked,
      version: data.version.present ? data.version.value : this.version,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KnownDevice(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tokenHash: $tokenHash, ')
          ..write('approved: $approved, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastAddress: $lastAddress, ')
          ..write('revoked: $revoked, ')
          ..write('version: $version')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    tokenHash,
    approved,
    createdAt,
    lastSeenAt,
    lastSyncAt,
    lastAddress,
    revoked,
    version,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KnownDevice &&
          other.id == this.id &&
          other.name == this.name &&
          other.tokenHash == this.tokenHash &&
          other.approved == this.approved &&
          other.createdAt == this.createdAt &&
          other.lastSeenAt == this.lastSeenAt &&
          other.lastSyncAt == this.lastSyncAt &&
          other.lastAddress == this.lastAddress &&
          other.revoked == this.revoked &&
          other.version == this.version);
}

class KnownDevicesCompanion extends UpdateCompanion<KnownDevice> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> tokenHash;
  final Value<bool> approved;
  final Value<int> createdAt;
  final Value<int?> lastSeenAt;
  final Value<int?> lastSyncAt;
  final Value<String?> lastAddress;
  final Value<bool> revoked;
  final Value<int> version;
  final Value<int> rowid;
  const KnownDevicesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.tokenHash = const Value.absent(),
    this.approved = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastSeenAt = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastAddress = const Value.absent(),
    this.revoked = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KnownDevicesCompanion.insert({
    required String id,
    required String name,
    required String tokenHash,
    this.approved = const Value.absent(),
    required int createdAt,
    this.lastSeenAt = const Value.absent(),
    this.lastSyncAt = const Value.absent(),
    this.lastAddress = const Value.absent(),
    this.revoked = const Value.absent(),
    this.version = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       tokenHash = Value(tokenHash),
       createdAt = Value(createdAt);
  static Insertable<KnownDevice> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? tokenHash,
    Expression<bool>? approved,
    Expression<int>? createdAt,
    Expression<int>? lastSeenAt,
    Expression<int>? lastSyncAt,
    Expression<String>? lastAddress,
    Expression<bool>? revoked,
    Expression<int>? version,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (tokenHash != null) 'token_hash': tokenHash,
      if (approved != null) 'approved': approved,
      if (createdAt != null) 'created_at': createdAt,
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt,
      if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
      if (lastAddress != null) 'last_address': lastAddress,
      if (revoked != null) 'revoked': revoked,
      if (version != null) 'version': version,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KnownDevicesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? tokenHash,
    Value<bool>? approved,
    Value<int>? createdAt,
    Value<int?>? lastSeenAt,
    Value<int?>? lastSyncAt,
    Value<String?>? lastAddress,
    Value<bool>? revoked,
    Value<int>? version,
    Value<int>? rowid,
  }) {
    return KnownDevicesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      tokenHash: tokenHash ?? this.tokenHash,
      approved: approved ?? this.approved,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastAddress: lastAddress ?? this.lastAddress,
      revoked: revoked ?? this.revoked,
      version: version ?? this.version,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (tokenHash.present) {
      map['token_hash'] = Variable<String>(tokenHash.value);
    }
    if (approved.present) {
      map['approved'] = Variable<bool>(approved.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (lastSeenAt.present) {
      map['last_seen_at'] = Variable<int>(lastSeenAt.value);
    }
    if (lastSyncAt.present) {
      map['last_sync_at'] = Variable<int>(lastSyncAt.value);
    }
    if (lastAddress.present) {
      map['last_address'] = Variable<String>(lastAddress.value);
    }
    if (revoked.present) {
      map['revoked'] = Variable<bool>(revoked.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KnownDevicesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('tokenHash: $tokenHash, ')
          ..write('approved: $approved, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastSeenAt: $lastSeenAt, ')
          ..write('lastSyncAt: $lastSyncAt, ')
          ..write('lastAddress: $lastAddress, ')
          ..write('revoked: $revoked, ')
          ..write('version: $version, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncChangesTable extends SyncChanges
    with TableInfo<$SyncChangesTable, SyncChange> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    operation,
    payload,
    version,
    deviceId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncChange> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncChange map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncChange(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncChangesTable createAlias(String alias) {
    return $SyncChangesTable(attachedDatabase, alias);
  }
}

class SyncChange extends DataClass implements Insertable<SyncChange> {
  final String id;
  final String entityType;
  final String entityId;
  final String operation;
  final String payload;
  final int version;
  final String deviceId;
  final int createdAt;
  const SyncChange({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.version,
    required this.deviceId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<String>(operation);
    map['payload'] = Variable<String>(payload);
    map['version'] = Variable<int>(version);
    map['device_id'] = Variable<String>(deviceId);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SyncChangesCompanion toCompanion(bool nullToAbsent) {
    return SyncChangesCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payload: Value(payload),
      version: Value(version),
      deviceId: Value(deviceId),
      createdAt: Value(createdAt),
    );
  }

  factory SyncChange.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncChange(
      id: serializer.fromJson<String>(json['id']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<String>(json['operation']),
      payload: serializer.fromJson<String>(json['payload']),
      version: serializer.fromJson<int>(json['version']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<String>(operation),
      'payload': serializer.toJson<String>(payload),
      'version': serializer.toJson<int>(version),
      'deviceId': serializer.toJson<String>(deviceId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SyncChange copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? operation,
    String? payload,
    int? version,
    String? deviceId,
    int? createdAt,
  }) => SyncChange(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    payload: payload ?? this.payload,
    version: version ?? this.version,
    deviceId: deviceId ?? this.deviceId,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncChange copyWithCompanion(SyncChangesCompanion data) {
    return SyncChange(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payload: data.payload.present ? data.payload.value : this.payload,
      version: data.version.present ? data.version.value : this.version,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncChange(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('version: $version, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    operation,
    payload,
    version,
    deviceId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncChange &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payload == this.payload &&
          other.version == this.version &&
          other.deviceId == this.deviceId &&
          other.createdAt == this.createdAt);
}

class SyncChangesCompanion extends UpdateCompanion<SyncChange> {
  final Value<String> id;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> operation;
  final Value<String> payload;
  final Value<int> version;
  final Value<String> deviceId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const SyncChangesCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payload = const Value.absent(),
    this.version = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncChangesCompanion.insert({
    required String id,
    required String entityType,
    required String entityId,
    required String operation,
    required String payload,
    required int version,
    required String deviceId,
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       payload = Value(payload),
       version = Value(version),
       deviceId = Value(deviceId),
       createdAt = Value(createdAt);
  static Insertable<SyncChange> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? operation,
    Expression<String>? payload,
    Expression<int>? version,
    Expression<String>? deviceId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payload != null) 'payload': payload,
      if (version != null) 'version': version,
      if (deviceId != null) 'device_id': deviceId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncChangesCompanion copyWith({
    Value<String>? id,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? operation,
    Value<String>? payload,
    Value<int>? version,
    Value<String>? deviceId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return SyncChangesCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      version: version ?? this.version,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncChangesCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payload: $payload, ')
          ..write('version: $version, ')
          ..write('deviceId: $deviceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  final int updatedAt;
  const AppSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  AppSetting copyWith({String? key, String? value, int? updatedAt}) =>
      AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LibrariesTable libraries = $LibrariesTable(this);
  late final $SectionsTable sections = $SectionsTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $PlaybackProgressTable playbackProgress = $PlaybackProgressTable(
    this,
  );
  late final $ReadingProgressTable readingProgress = $ReadingProgressTable(
    this,
  );
  late final $NotesTable notes = $NotesTable(this);
  late final $BookmarksTable bookmarks = $BookmarksTable(this);
  late final $KnownDevicesTable knownDevices = $KnownDevicesTable(this);
  late final $SyncChangesTable syncChanges = $SyncChangesTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    libraries,
    sections,
    items,
    playbackProgress,
    readingProgress,
    notes,
    bookmarks,
    knownDevices,
    syncChanges,
    appSettings,
  ];
}

typedef $$LibrariesTableCreateCompanionBuilder =
    LibrariesCompanion Function({
      required String id,
      required String title,
      Value<String> description,
      required String rootFolderPath,
      Value<String?> coverPath,
      required int createdAt,
      required int updatedAt,
      Value<int?> lastScannedAt,
      Value<bool> unavailable,
      Value<int> version,
      Value<String> updatedByDevice,
      Value<int> rowid,
    });
typedef $$LibrariesTableUpdateCompanionBuilder =
    LibrariesCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> description,
      Value<String> rootFolderPath,
      Value<String?> coverPath,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int?> lastScannedAt,
      Value<bool> unavailable,
      Value<int> version,
      Value<String> updatedByDevice,
      Value<int> rowid,
    });

final class $$LibrariesTableReferences
    extends BaseReferences<_$AppDatabase, $LibrariesTable, Library> {
  $$LibrariesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SectionsTable, List<Section>> _sectionsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.sections,
    aliasName: $_aliasNameGenerator(db.libraries.id, db.sections.libraryId),
  );

  $$SectionsTableProcessedTableManager get sectionsRefs {
    final manager = $$SectionsTableTableManager(
      $_db,
      $_db.sections,
    ).filter((f) => f.libraryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_sectionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ItemsTable, List<Item>> _itemsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.items,
    aliasName: $_aliasNameGenerator(db.libraries.id, db.items.libraryId),
  );

  $$ItemsTableProcessedTableManager get itemsRefs {
    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.libraryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: $_aliasNameGenerator(db.libraries.id, db.notes.libraryId),
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.libraryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarksTable, List<Bookmark>>
  _bookmarksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarks,
    aliasName: $_aliasNameGenerator(db.libraries.id, db.bookmarks.libraryId),
  );

  $$BookmarksTableProcessedTableManager get bookmarksRefs {
    final manager = $$BookmarksTableTableManager(
      $_db,
      $_db.bookmarks,
    ).filter((f) => f.libraryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookmarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LibrariesTableFilterComposer
    extends Composer<_$AppDatabase, $LibrariesTable> {
  $$LibrariesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootFolderPath => $composableBuilder(
    column: $table.rootFolderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastScannedAt => $composableBuilder(
    column: $table.lastScannedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unavailable => $composableBuilder(
    column: $table.unavailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedByDevice => $composableBuilder(
    column: $table.updatedByDevice,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> sectionsRefs(
    Expression<bool> Function($$SectionsTableFilterComposer f) f,
  ) {
    final $$SectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sections,
      getReferencedColumn: (t) => t.libraryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionsTableFilterComposer(
            $db: $db,
            $table: $db.sections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> itemsRefs(
    Expression<bool> Function($$ItemsTableFilterComposer f) f,
  ) {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.libraryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.libraryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarksRefs(
    Expression<bool> Function($$BookmarksTableFilterComposer f) f,
  ) {
    final $$BookmarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.libraryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableFilterComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibrariesTableOrderingComposer
    extends Composer<_$AppDatabase, $LibrariesTable> {
  $$LibrariesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootFolderPath => $composableBuilder(
    column: $table.rootFolderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get coverPath => $composableBuilder(
    column: $table.coverPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastScannedAt => $composableBuilder(
    column: $table.lastScannedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unavailable => $composableBuilder(
    column: $table.unavailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedByDevice => $composableBuilder(
    column: $table.updatedByDevice,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LibrariesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LibrariesTable> {
  $$LibrariesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rootFolderPath => $composableBuilder(
    column: $table.rootFolderPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get coverPath =>
      $composableBuilder(column: $table.coverPath, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get lastScannedAt => $composableBuilder(
    column: $table.lastScannedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get unavailable => $composableBuilder(
    column: $table.unavailable,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get updatedByDevice => $composableBuilder(
    column: $table.updatedByDevice,
    builder: (column) => column,
  );

  Expression<T> sectionsRefs<T extends Object>(
    Expression<T> Function($$SectionsTableAnnotationComposer a) f,
  ) {
    final $$SectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sections,
      getReferencedColumn: (t) => t.libraryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> itemsRefs<T extends Object>(
    Expression<T> Function($$ItemsTableAnnotationComposer a) f,
  ) {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.libraryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.libraryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookmarksRefs<T extends Object>(
    Expression<T> Function($$BookmarksTableAnnotationComposer a) f,
  ) {
    final $$BookmarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.libraryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LibrariesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LibrariesTable,
          Library,
          $$LibrariesTableFilterComposer,
          $$LibrariesTableOrderingComposer,
          $$LibrariesTableAnnotationComposer,
          $$LibrariesTableCreateCompanionBuilder,
          $$LibrariesTableUpdateCompanionBuilder,
          (Library, $$LibrariesTableReferences),
          Library,
          PrefetchHooks Function({
            bool sectionsRefs,
            bool itemsRefs,
            bool notesRefs,
            bool bookmarksRefs,
          })
        > {
  $$LibrariesTableTableManager(_$AppDatabase db, $LibrariesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LibrariesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LibrariesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LibrariesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> rootFolderPath = const Value.absent(),
                Value<String?> coverPath = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int?> lastScannedAt = const Value.absent(),
                Value<bool> unavailable = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> updatedByDevice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibrariesCompanion(
                id: id,
                title: title,
                description: description,
                rootFolderPath: rootFolderPath,
                coverPath: coverPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastScannedAt: lastScannedAt,
                unavailable: unavailable,
                version: version,
                updatedByDevice: updatedByDevice,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<String> description = const Value.absent(),
                required String rootFolderPath,
                Value<String?> coverPath = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                Value<int?> lastScannedAt = const Value.absent(),
                Value<bool> unavailable = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> updatedByDevice = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LibrariesCompanion.insert(
                id: id,
                title: title,
                description: description,
                rootFolderPath: rootFolderPath,
                coverPath: coverPath,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastScannedAt: lastScannedAt,
                unavailable: unavailable,
                version: version,
                updatedByDevice: updatedByDevice,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LibrariesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sectionsRefs = false,
                itemsRefs = false,
                notesRefs = false,
                bookmarksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sectionsRefs) db.sections,
                    if (itemsRefs) db.items,
                    if (notesRefs) db.notes,
                    if (bookmarksRefs) db.bookmarks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sectionsRefs)
                        await $_getPrefetchedData<
                          Library,
                          $LibrariesTable,
                          Section
                        >(
                          currentTable: table,
                          referencedTable: $$LibrariesTableReferences
                              ._sectionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibrariesTableReferences(
                                db,
                                table,
                                p0,
                              ).sectionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.libraryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (itemsRefs)
                        await $_getPrefetchedData<
                          Library,
                          $LibrariesTable,
                          Item
                        >(
                          currentTable: table,
                          referencedTable: $$LibrariesTableReferences
                              ._itemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibrariesTableReferences(
                                db,
                                table,
                                p0,
                              ).itemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.libraryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (notesRefs)
                        await $_getPrefetchedData<
                          Library,
                          $LibrariesTable,
                          Note
                        >(
                          currentTable: table,
                          referencedTable: $$LibrariesTableReferences
                              ._notesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibrariesTableReferences(
                                db,
                                table,
                                p0,
                              ).notesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.libraryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarksRefs)
                        await $_getPrefetchedData<
                          Library,
                          $LibrariesTable,
                          Bookmark
                        >(
                          currentTable: table,
                          referencedTable: $$LibrariesTableReferences
                              ._bookmarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$LibrariesTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.libraryId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$LibrariesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LibrariesTable,
      Library,
      $$LibrariesTableFilterComposer,
      $$LibrariesTableOrderingComposer,
      $$LibrariesTableAnnotationComposer,
      $$LibrariesTableCreateCompanionBuilder,
      $$LibrariesTableUpdateCompanionBuilder,
      (Library, $$LibrariesTableReferences),
      Library,
      PrefetchHooks Function({
        bool sectionsRefs,
        bool itemsRefs,
        bool notesRefs,
        bool bookmarksRefs,
      })
    >;
typedef $$SectionsTableCreateCompanionBuilder =
    SectionsCompanion Function({
      required String id,
      required String libraryId,
      required String title,
      Value<String> relativePath,
      Value<String?> parentSectionId,
      required int orderIndex,
      required String folderPath,
      Value<int> itemCount,
      Value<int> completedCount,
      Value<bool> unavailable,
      Value<int> updatedAt,
      Value<int> rowid,
    });
typedef $$SectionsTableUpdateCompanionBuilder =
    SectionsCompanion Function({
      Value<String> id,
      Value<String> libraryId,
      Value<String> title,
      Value<String> relativePath,
      Value<String?> parentSectionId,
      Value<int> orderIndex,
      Value<String> folderPath,
      Value<int> itemCount,
      Value<int> completedCount,
      Value<bool> unavailable,
      Value<int> updatedAt,
      Value<int> rowid,
    });

final class $$SectionsTableReferences
    extends BaseReferences<_$AppDatabase, $SectionsTable, Section> {
  $$SectionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibrariesTable _libraryIdTable(_$AppDatabase db) =>
      db.libraries.createAlias(
        $_aliasNameGenerator(db.sections.libraryId, db.libraries.id),
      );

  $$LibrariesTableProcessedTableManager get libraryId {
    final $_column = $_itemColumn<String>('library_id')!;

    final manager = $$LibrariesTableTableManager(
      $_db,
      $_db.libraries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_libraryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ItemsTable, List<Item>> _itemsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.items,
    aliasName: $_aliasNameGenerator(db.sections.id, db.items.sectionId),
  );

  $$ItemsTableProcessedTableManager get itemsRefs {
    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.sectionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_itemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SectionsTableFilterComposer
    extends Composer<_$AppDatabase, $SectionsTable> {
  $$SectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentSectionId => $composableBuilder(
    column: $table.parentSectionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedCount => $composableBuilder(
    column: $table.completedCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unavailable => $composableBuilder(
    column: $table.unavailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$LibrariesTableFilterComposer get libraryId {
    final $$LibrariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableFilterComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> itemsRefs(
    Expression<bool> Function($$ItemsTableFilterComposer f) f,
  ) {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.sectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SectionsTable> {
  $$SectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentSectionId => $composableBuilder(
    column: $table.parentSectionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedCount => $composableBuilder(
    column: $table.completedCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unavailable => $composableBuilder(
    column: $table.unavailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibrariesTableOrderingComposer get libraryId {
    final $$LibrariesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableOrderingComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SectionsTable> {
  $$SectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentSectionId => $composableBuilder(
    column: $table.parentSectionId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get folderPath => $composableBuilder(
    column: $table.folderPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<int> get completedCount => $composableBuilder(
    column: $table.completedCount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get unavailable => $composableBuilder(
    column: $table.unavailable,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$LibrariesTableAnnotationComposer get libraryId {
    final $$LibrariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableAnnotationComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> itemsRefs<T extends Object>(
    Expression<T> Function($$ItemsTableAnnotationComposer a) f,
  ) {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.sectionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SectionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SectionsTable,
          Section,
          $$SectionsTableFilterComposer,
          $$SectionsTableOrderingComposer,
          $$SectionsTableAnnotationComposer,
          $$SectionsTableCreateCompanionBuilder,
          $$SectionsTableUpdateCompanionBuilder,
          (Section, $$SectionsTableReferences),
          Section,
          PrefetchHooks Function({bool libraryId, bool itemsRefs})
        > {
  $$SectionsTableTableManager(_$AppDatabase db, $SectionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> libraryId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String?> parentSectionId = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<String> folderPath = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<int> completedCount = const Value.absent(),
                Value<bool> unavailable = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SectionsCompanion(
                id: id,
                libraryId: libraryId,
                title: title,
                relativePath: relativePath,
                parentSectionId: parentSectionId,
                orderIndex: orderIndex,
                folderPath: folderPath,
                itemCount: itemCount,
                completedCount: completedCount,
                unavailable: unavailable,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String libraryId,
                required String title,
                Value<String> relativePath = const Value.absent(),
                Value<String?> parentSectionId = const Value.absent(),
                required int orderIndex,
                required String folderPath,
                Value<int> itemCount = const Value.absent(),
                Value<int> completedCount = const Value.absent(),
                Value<bool> unavailable = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SectionsCompanion.insert(
                id: id,
                libraryId: libraryId,
                title: title,
                relativePath: relativePath,
                parentSectionId: parentSectionId,
                orderIndex: orderIndex,
                folderPath: folderPath,
                itemCount: itemCount,
                completedCount: completedCount,
                unavailable: unavailable,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SectionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({libraryId = false, itemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (itemsRefs) db.items],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (libraryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.libraryId,
                                referencedTable: $$SectionsTableReferences
                                    ._libraryIdTable(db),
                                referencedColumn: $$SectionsTableReferences
                                    ._libraryIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (itemsRefs)
                    await $_getPrefetchedData<Section, $SectionsTable, Item>(
                      currentTable: table,
                      referencedTable: $$SectionsTableReferences
                          ._itemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SectionsTableReferences(db, table, p0).itemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sectionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SectionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SectionsTable,
      Section,
      $$SectionsTableFilterComposer,
      $$SectionsTableOrderingComposer,
      $$SectionsTableAnnotationComposer,
      $$SectionsTableCreateCompanionBuilder,
      $$SectionsTableUpdateCompanionBuilder,
      (Section, $$SectionsTableReferences),
      Section,
      PrefetchHooks Function({bool libraryId, bool itemsRefs})
    >;
typedef $$ItemsTableCreateCompanionBuilder =
    ItemsCompanion Function({
      required String id,
      required String libraryId,
      required String sectionId,
      required String title,
      Value<String?> userTitle,
      required String filename,
      required String filePath,
      required String relativePath,
      required String itemType,
      required int orderIndex,
      Value<double?> durationSeconds,
      Value<int?> pageCount,
      Value<String?> thumbnailPath,
      Value<int?> modifiedAt,
      Value<int?> fileSize,
      Value<String?> fingerprint,
      Value<bool> unavailable,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$ItemsTableUpdateCompanionBuilder =
    ItemsCompanion Function({
      Value<String> id,
      Value<String> libraryId,
      Value<String> sectionId,
      Value<String> title,
      Value<String?> userTitle,
      Value<String> filename,
      Value<String> filePath,
      Value<String> relativePath,
      Value<String> itemType,
      Value<int> orderIndex,
      Value<double?> durationSeconds,
      Value<int?> pageCount,
      Value<String?> thumbnailPath,
      Value<int?> modifiedAt,
      Value<int?> fileSize,
      Value<String?> fingerprint,
      Value<bool> unavailable,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<int> version,
      Value<int> rowid,
    });

final class $$ItemsTableReferences
    extends BaseReferences<_$AppDatabase, $ItemsTable, Item> {
  $$ItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibrariesTable _libraryIdTable(_$AppDatabase db) => db.libraries
      .createAlias($_aliasNameGenerator(db.items.libraryId, db.libraries.id));

  $$LibrariesTableProcessedTableManager get libraryId {
    final $_column = $_itemColumn<String>('library_id')!;

    final manager = $$LibrariesTableTableManager(
      $_db,
      $_db.libraries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_libraryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SectionsTable _sectionIdTable(_$AppDatabase db) => db.sections
      .createAlias($_aliasNameGenerator(db.items.sectionId, db.sections.id));

  $$SectionsTableProcessedTableManager get sectionId {
    final $_column = $_itemColumn<String>('section_id')!;

    final manager = $$SectionsTableTableManager(
      $_db,
      $_db.sections,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sectionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PlaybackProgressTable, List<PlaybackProgressData>>
  _playbackProgressRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.playbackProgress,
    aliasName: $_aliasNameGenerator(db.items.id, db.playbackProgress.itemId),
  );

  $$PlaybackProgressTableProcessedTableManager get playbackProgressRefs {
    final manager = $$PlaybackProgressTableTableManager(
      $_db,
      $_db.playbackProgress,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _playbackProgressRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ReadingProgressTable, List<ReadingProgressData>>
  _readingProgressRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.readingProgress,
    aliasName: $_aliasNameGenerator(db.items.id, db.readingProgress.itemId),
  );

  $$ReadingProgressTableProcessedTableManager get readingProgressRefs {
    final manager = $$ReadingProgressTableTableManager(
      $_db,
      $_db.readingProgress,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _readingProgressRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NotesTable, List<Note>> _notesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: $_aliasNameGenerator(db.items.id, db.notes.itemId),
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$BookmarksTable, List<Bookmark>>
  _bookmarksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.bookmarks,
    aliasName: $_aliasNameGenerator(db.items.id, db.bookmarks.itemId),
  );

  $$BookmarksTableProcessedTableManager get bookmarksRefs {
    final manager = $$BookmarksTableTableManager(
      $_db,
      $_db.bookmarks,
    ).filter((f) => f.itemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_bookmarksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userTitle => $composableBuilder(
    column: $table.userTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get unavailable => $composableBuilder(
    column: $table.unavailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  $$LibrariesTableFilterComposer get libraryId {
    final $$LibrariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableFilterComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SectionsTableFilterComposer get sectionId {
    final $$SectionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sectionId,
      referencedTable: $db.sections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionsTableFilterComposer(
            $db: $db,
            $table: $db.sections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> playbackProgressRefs(
    Expression<bool> Function($$PlaybackProgressTableFilterComposer f) f,
  ) {
    final $$PlaybackProgressTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playbackProgress,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackProgressTableFilterComposer(
            $db: $db,
            $table: $db.playbackProgress,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> readingProgressRefs(
    Expression<bool> Function($$ReadingProgressTableFilterComposer f) f,
  ) {
    final $$ReadingProgressTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgress,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressTableFilterComposer(
            $db: $db,
            $table: $db.readingProgress,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> bookmarksRefs(
    Expression<bool> Function($$BookmarksTableFilterComposer f) f,
  ) {
    final $$BookmarksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableFilterComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userTitle => $composableBuilder(
    column: $table.userTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemType => $composableBuilder(
    column: $table.itemType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageCount => $composableBuilder(
    column: $table.pageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get unavailable => $composableBuilder(
    column: $table.unavailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibrariesTableOrderingComposer get libraryId {
    final $$LibrariesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableOrderingComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SectionsTableOrderingComposer get sectionId {
    final $$SectionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sectionId,
      referencedTable: $db.sections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionsTableOrderingComposer(
            $db: $db,
            $table: $db.sections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get userTitle =>
      $composableBuilder(column: $table.userTitle, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get itemType =>
      $composableBuilder(column: $table.itemType, builder: (column) => column);

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageCount =>
      $composableBuilder(column: $table.pageCount, builder: (column) => column);

  GeneratedColumn<String> get thumbnailPath => $composableBuilder(
    column: $table.thumbnailPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get modifiedAt => $composableBuilder(
    column: $table.modifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get unavailable => $composableBuilder(
    column: $table.unavailable,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  $$LibrariesTableAnnotationComposer get libraryId {
    final $$LibrariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableAnnotationComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SectionsTableAnnotationComposer get sectionId {
    final $$SectionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sectionId,
      referencedTable: $db.sections,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SectionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sections,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> playbackProgressRefs<T extends Object>(
    Expression<T> Function($$PlaybackProgressTableAnnotationComposer a) f,
  ) {
    final $$PlaybackProgressTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.playbackProgress,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PlaybackProgressTableAnnotationComposer(
            $db: $db,
            $table: $db.playbackProgress,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> readingProgressRefs<T extends Object>(
    Expression<T> Function($$ReadingProgressTableAnnotationComposer a) f,
  ) {
    final $$ReadingProgressTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.readingProgress,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ReadingProgressTableAnnotationComposer(
            $db: $db,
            $table: $db.readingProgress,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> bookmarksRefs<T extends Object>(
    Expression<T> Function($$BookmarksTableAnnotationComposer a) f,
  ) {
    final $$BookmarksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.bookmarks,
      getReferencedColumn: (t) => t.itemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BookmarksTableAnnotationComposer(
            $db: $db,
            $table: $db.bookmarks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ItemsTable,
          Item,
          $$ItemsTableFilterComposer,
          $$ItemsTableOrderingComposer,
          $$ItemsTableAnnotationComposer,
          $$ItemsTableCreateCompanionBuilder,
          $$ItemsTableUpdateCompanionBuilder,
          (Item, $$ItemsTableReferences),
          Item,
          PrefetchHooks Function({
            bool libraryId,
            bool sectionId,
            bool playbackProgressRefs,
            bool readingProgressRefs,
            bool notesRefs,
            bool bookmarksRefs,
          })
        > {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> libraryId = const Value.absent(),
                Value<String> sectionId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> userTitle = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> itemType = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<double?> durationSeconds = const Value.absent(),
                Value<int?> pageCount = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<int?> modifiedAt = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<bool> unavailable = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion(
                id: id,
                libraryId: libraryId,
                sectionId: sectionId,
                title: title,
                userTitle: userTitle,
                filename: filename,
                filePath: filePath,
                relativePath: relativePath,
                itemType: itemType,
                orderIndex: orderIndex,
                durationSeconds: durationSeconds,
                pageCount: pageCount,
                thumbnailPath: thumbnailPath,
                modifiedAt: modifiedAt,
                fileSize: fileSize,
                fingerprint: fingerprint,
                unavailable: unavailable,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String libraryId,
                required String sectionId,
                required String title,
                Value<String?> userTitle = const Value.absent(),
                required String filename,
                required String filePath,
                required String relativePath,
                required String itemType,
                required int orderIndex,
                Value<double?> durationSeconds = const Value.absent(),
                Value<int?> pageCount = const Value.absent(),
                Value<String?> thumbnailPath = const Value.absent(),
                Value<int?> modifiedAt = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<bool> unavailable = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ItemsCompanion.insert(
                id: id,
                libraryId: libraryId,
                sectionId: sectionId,
                title: title,
                userTitle: userTitle,
                filename: filename,
                filePath: filePath,
                relativePath: relativePath,
                itemType: itemType,
                orderIndex: orderIndex,
                durationSeconds: durationSeconds,
                pageCount: pageCount,
                thumbnailPath: thumbnailPath,
                modifiedAt: modifiedAt,
                fileSize: fileSize,
                fingerprint: fingerprint,
                unavailable: unavailable,
                createdAt: createdAt,
                updatedAt: updatedAt,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ItemsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                libraryId = false,
                sectionId = false,
                playbackProgressRefs = false,
                readingProgressRefs = false,
                notesRefs = false,
                bookmarksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (playbackProgressRefs) db.playbackProgress,
                    if (readingProgressRefs) db.readingProgress,
                    if (notesRefs) db.notes,
                    if (bookmarksRefs) db.bookmarks,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (libraryId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.libraryId,
                                    referencedTable: $$ItemsTableReferences
                                        ._libraryIdTable(db),
                                    referencedColumn: $$ItemsTableReferences
                                        ._libraryIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (sectionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sectionId,
                                    referencedTable: $$ItemsTableReferences
                                        ._sectionIdTable(db),
                                    referencedColumn: $$ItemsTableReferences
                                        ._sectionIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (playbackProgressRefs)
                        await $_getPrefetchedData<
                          Item,
                          $ItemsTable,
                          PlaybackProgressData
                        >(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._playbackProgressRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).playbackProgressRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (readingProgressRefs)
                        await $_getPrefetchedData<
                          Item,
                          $ItemsTable,
                          ReadingProgressData
                        >(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._readingProgressRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).readingProgressRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (notesRefs)
                        await $_getPrefetchedData<Item, $ItemsTable, Note>(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._notesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(db, table, p0).notesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (bookmarksRefs)
                        await $_getPrefetchedData<Item, $ItemsTable, Bookmark>(
                          currentTable: table,
                          referencedTable: $$ItemsTableReferences
                              ._bookmarksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).bookmarksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.itemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ItemsTable,
      Item,
      $$ItemsTableFilterComposer,
      $$ItemsTableOrderingComposer,
      $$ItemsTableAnnotationComposer,
      $$ItemsTableCreateCompanionBuilder,
      $$ItemsTableUpdateCompanionBuilder,
      (Item, $$ItemsTableReferences),
      Item,
      PrefetchHooks Function({
        bool libraryId,
        bool sectionId,
        bool playbackProgressRefs,
        bool readingProgressRefs,
        bool notesRefs,
        bool bookmarksRefs,
      })
    >;
typedef $$PlaybackProgressTableCreateCompanionBuilder =
    PlaybackProgressCompanion Function({
      required String itemId,
      Value<double> lastPositionSeconds,
      Value<double> resumePositionSeconds,
      Value<double> durationSeconds,
      Value<double> percentWatched,
      Value<bool> completed,
      Value<bool?> manualCompletion,
      Value<double> playbackSpeed,
      Value<int> lastOpenedAt,
      Value<int> lastEventAt,
      required String deviceId,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$PlaybackProgressTableUpdateCompanionBuilder =
    PlaybackProgressCompanion Function({
      Value<String> itemId,
      Value<double> lastPositionSeconds,
      Value<double> resumePositionSeconds,
      Value<double> durationSeconds,
      Value<double> percentWatched,
      Value<bool> completed,
      Value<bool?> manualCompletion,
      Value<double> playbackSpeed,
      Value<int> lastOpenedAt,
      Value<int> lastEventAt,
      Value<String> deviceId,
      Value<int> version,
      Value<int> rowid,
    });

final class $$PlaybackProgressTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PlaybackProgressTable,
          PlaybackProgressData
        > {
  $$PlaybackProgressTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items.createAlias(
    $_aliasNameGenerator(db.playbackProgress.itemId, db.items.id),
  );

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PlaybackProgressTableFilterComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<double> get lastPositionSeconds => $composableBuilder(
    column: $table.lastPositionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get resumePositionSeconds => $composableBuilder(
    column: $table.resumePositionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percentWatched => $composableBuilder(
    column: $table.percentWatched,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get manualCompletion => $composableBuilder(
    column: $table.manualCompletion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get playbackSpeed => $composableBuilder(
    column: $table.playbackSpeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastEventAt => $composableBuilder(
    column: $table.lastEventAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<double> get lastPositionSeconds => $composableBuilder(
    column: $table.lastPositionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get resumePositionSeconds => $composableBuilder(
    column: $table.resumePositionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percentWatched => $composableBuilder(
    column: $table.percentWatched,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get manualCompletion => $composableBuilder(
    column: $table.manualCompletion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get playbackSpeed => $composableBuilder(
    column: $table.playbackSpeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastEventAt => $composableBuilder(
    column: $table.lastEventAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlaybackProgressTable> {
  $$PlaybackProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<double> get lastPositionSeconds => $composableBuilder(
    column: $table.lastPositionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get resumePositionSeconds => $composableBuilder(
    column: $table.resumePositionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get percentWatched => $composableBuilder(
    column: $table.percentWatched,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<bool> get manualCompletion => $composableBuilder(
    column: $table.manualCompletion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get playbackSpeed => $composableBuilder(
    column: $table.playbackSpeed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastEventAt => $composableBuilder(
    column: $table.lastEventAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PlaybackProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlaybackProgressTable,
          PlaybackProgressData,
          $$PlaybackProgressTableFilterComposer,
          $$PlaybackProgressTableOrderingComposer,
          $$PlaybackProgressTableAnnotationComposer,
          $$PlaybackProgressTableCreateCompanionBuilder,
          $$PlaybackProgressTableUpdateCompanionBuilder,
          (PlaybackProgressData, $$PlaybackProgressTableReferences),
          PlaybackProgressData,
          PrefetchHooks Function({bool itemId})
        > {
  $$PlaybackProgressTableTableManager(
    _$AppDatabase db,
    $PlaybackProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlaybackProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlaybackProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlaybackProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<double> lastPositionSeconds = const Value.absent(),
                Value<double> resumePositionSeconds = const Value.absent(),
                Value<double> durationSeconds = const Value.absent(),
                Value<double> percentWatched = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool?> manualCompletion = const Value.absent(),
                Value<double> playbackSpeed = const Value.absent(),
                Value<int> lastOpenedAt = const Value.absent(),
                Value<int> lastEventAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackProgressCompanion(
                itemId: itemId,
                lastPositionSeconds: lastPositionSeconds,
                resumePositionSeconds: resumePositionSeconds,
                durationSeconds: durationSeconds,
                percentWatched: percentWatched,
                completed: completed,
                manualCompletion: manualCompletion,
                playbackSpeed: playbackSpeed,
                lastOpenedAt: lastOpenedAt,
                lastEventAt: lastEventAt,
                deviceId: deviceId,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                Value<double> lastPositionSeconds = const Value.absent(),
                Value<double> resumePositionSeconds = const Value.absent(),
                Value<double> durationSeconds = const Value.absent(),
                Value<double> percentWatched = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool?> manualCompletion = const Value.absent(),
                Value<double> playbackSpeed = const Value.absent(),
                Value<int> lastOpenedAt = const Value.absent(),
                Value<int> lastEventAt = const Value.absent(),
                required String deviceId,
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlaybackProgressCompanion.insert(
                itemId: itemId,
                lastPositionSeconds: lastPositionSeconds,
                resumePositionSeconds: resumePositionSeconds,
                durationSeconds: durationSeconds,
                percentWatched: percentWatched,
                completed: completed,
                manualCompletion: manualCompletion,
                playbackSpeed: playbackSpeed,
                lastOpenedAt: lastOpenedAt,
                lastEventAt: lastEventAt,
                deviceId: deviceId,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PlaybackProgressTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable:
                                    $$PlaybackProgressTableReferences
                                        ._itemIdTable(db),
                                referencedColumn:
                                    $$PlaybackProgressTableReferences
                                        ._itemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PlaybackProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlaybackProgressTable,
      PlaybackProgressData,
      $$PlaybackProgressTableFilterComposer,
      $$PlaybackProgressTableOrderingComposer,
      $$PlaybackProgressTableAnnotationComposer,
      $$PlaybackProgressTableCreateCompanionBuilder,
      $$PlaybackProgressTableUpdateCompanionBuilder,
      (PlaybackProgressData, $$PlaybackProgressTableReferences),
      PlaybackProgressData,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$ReadingProgressTableCreateCompanionBuilder =
    ReadingProgressCompanion Function({
      required String itemId,
      Value<int> lastPage,
      Value<double> lastScrollOffset,
      Value<int> resumePage,
      Value<double> resumeScrollOffset,
      Value<double> percentRead,
      Value<bool> completed,
      Value<bool?> manualCompletion,
      Value<double> zoom,
      Value<String> readingMode,
      Value<int> lastOpenedAt,
      Value<int> lastEventAt,
      required String deviceId,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$ReadingProgressTableUpdateCompanionBuilder =
    ReadingProgressCompanion Function({
      Value<String> itemId,
      Value<int> lastPage,
      Value<double> lastScrollOffset,
      Value<int> resumePage,
      Value<double> resumeScrollOffset,
      Value<double> percentRead,
      Value<bool> completed,
      Value<bool?> manualCompletion,
      Value<double> zoom,
      Value<String> readingMode,
      Value<int> lastOpenedAt,
      Value<int> lastEventAt,
      Value<String> deviceId,
      Value<int> version,
      Value<int> rowid,
    });

final class $$ReadingProgressTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData
        > {
  $$ReadingProgressTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items.createAlias(
    $_aliasNameGenerator(db.readingProgress.itemId, db.items.id),
  );

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ReadingProgressTableFilterComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get lastPage => $composableBuilder(
    column: $table.lastPage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastScrollOffset => $composableBuilder(
    column: $table.lastScrollOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get resumePage => $composableBuilder(
    column: $table.resumePage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get resumeScrollOffset => $composableBuilder(
    column: $table.resumeScrollOffset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get percentRead => $composableBuilder(
    column: $table.percentRead,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get manualCompletion => $composableBuilder(
    column: $table.manualCompletion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get zoom => $composableBuilder(
    column: $table.zoom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get readingMode => $composableBuilder(
    column: $table.readingMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastEventAt => $composableBuilder(
    column: $table.lastEventAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get lastPage => $composableBuilder(
    column: $table.lastPage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastScrollOffset => $composableBuilder(
    column: $table.lastScrollOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get resumePage => $composableBuilder(
    column: $table.resumePage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get resumeScrollOffset => $composableBuilder(
    column: $table.resumeScrollOffset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get percentRead => $composableBuilder(
    column: $table.percentRead,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get completed => $composableBuilder(
    column: $table.completed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get manualCompletion => $composableBuilder(
    column: $table.manualCompletion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get zoom => $composableBuilder(
    column: $table.zoom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get readingMode => $composableBuilder(
    column: $table.readingMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastEventAt => $composableBuilder(
    column: $table.lastEventAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReadingProgressTable> {
  $$ReadingProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get lastPage =>
      $composableBuilder(column: $table.lastPage, builder: (column) => column);

  GeneratedColumn<double> get lastScrollOffset => $composableBuilder(
    column: $table.lastScrollOffset,
    builder: (column) => column,
  );

  GeneratedColumn<int> get resumePage => $composableBuilder(
    column: $table.resumePage,
    builder: (column) => column,
  );

  GeneratedColumn<double> get resumeScrollOffset => $composableBuilder(
    column: $table.resumeScrollOffset,
    builder: (column) => column,
  );

  GeneratedColumn<double> get percentRead => $composableBuilder(
    column: $table.percentRead,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get completed =>
      $composableBuilder(column: $table.completed, builder: (column) => column);

  GeneratedColumn<bool> get manualCompletion => $composableBuilder(
    column: $table.manualCompletion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get zoom =>
      $composableBuilder(column: $table.zoom, builder: (column) => column);

  GeneratedColumn<String> get readingMode => $composableBuilder(
    column: $table.readingMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastEventAt => $composableBuilder(
    column: $table.lastEventAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ReadingProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingProgressTable,
          ReadingProgressData,
          $$ReadingProgressTableFilterComposer,
          $$ReadingProgressTableOrderingComposer,
          $$ReadingProgressTableAnnotationComposer,
          $$ReadingProgressTableCreateCompanionBuilder,
          $$ReadingProgressTableUpdateCompanionBuilder,
          (ReadingProgressData, $$ReadingProgressTableReferences),
          ReadingProgressData,
          PrefetchHooks Function({bool itemId})
        > {
  $$ReadingProgressTableTableManager(
    _$AppDatabase db,
    $ReadingProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReadingProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReadingProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReadingProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<int> lastPage = const Value.absent(),
                Value<double> lastScrollOffset = const Value.absent(),
                Value<int> resumePage = const Value.absent(),
                Value<double> resumeScrollOffset = const Value.absent(),
                Value<double> percentRead = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool?> manualCompletion = const Value.absent(),
                Value<double> zoom = const Value.absent(),
                Value<String> readingMode = const Value.absent(),
                Value<int> lastOpenedAt = const Value.absent(),
                Value<int> lastEventAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion(
                itemId: itemId,
                lastPage: lastPage,
                lastScrollOffset: lastScrollOffset,
                resumePage: resumePage,
                resumeScrollOffset: resumeScrollOffset,
                percentRead: percentRead,
                completed: completed,
                manualCompletion: manualCompletion,
                zoom: zoom,
                readingMode: readingMode,
                lastOpenedAt: lastOpenedAt,
                lastEventAt: lastEventAt,
                deviceId: deviceId,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemId,
                Value<int> lastPage = const Value.absent(),
                Value<double> lastScrollOffset = const Value.absent(),
                Value<int> resumePage = const Value.absent(),
                Value<double> resumeScrollOffset = const Value.absent(),
                Value<double> percentRead = const Value.absent(),
                Value<bool> completed = const Value.absent(),
                Value<bool?> manualCompletion = const Value.absent(),
                Value<double> zoom = const Value.absent(),
                Value<String> readingMode = const Value.absent(),
                Value<int> lastOpenedAt = const Value.absent(),
                Value<int> lastEventAt = const Value.absent(),
                required String deviceId,
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReadingProgressCompanion.insert(
                itemId: itemId,
                lastPage: lastPage,
                lastScrollOffset: lastScrollOffset,
                resumePage: resumePage,
                resumeScrollOffset: resumeScrollOffset,
                percentRead: percentRead,
                completed: completed,
                manualCompletion: manualCompletion,
                zoom: zoom,
                readingMode: readingMode,
                lastOpenedAt: lastOpenedAt,
                lastEventAt: lastEventAt,
                deviceId: deviceId,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ReadingProgressTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable:
                                    $$ReadingProgressTableReferences
                                        ._itemIdTable(db),
                                referencedColumn:
                                    $$ReadingProgressTableReferences
                                        ._itemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ReadingProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingProgressTable,
      ReadingProgressData,
      $$ReadingProgressTableFilterComposer,
      $$ReadingProgressTableOrderingComposer,
      $$ReadingProgressTableAnnotationComposer,
      $$ReadingProgressTableCreateCompanionBuilder,
      $$ReadingProgressTableUpdateCompanionBuilder,
      (ReadingProgressData, $$ReadingProgressTableReferences),
      ReadingProgressData,
      PrefetchHooks Function({bool itemId})
    >;
typedef $$NotesTableCreateCompanionBuilder =
    NotesCompanion Function({
      required String id,
      required String libraryId,
      Value<String?> itemId,
      required String content,
      Value<double?> positionSeconds,
      Value<int?> pageNumber,
      required int createdAt,
      required int updatedAt,
      required String deviceId,
      Value<int> version,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$NotesTableUpdateCompanionBuilder =
    NotesCompanion Function({
      Value<String> id,
      Value<String> libraryId,
      Value<String?> itemId,
      Value<String> content,
      Value<double?> positionSeconds,
      Value<int?> pageNumber,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int> version,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$NotesTableReferences
    extends BaseReferences<_$AppDatabase, $NotesTable, Note> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibrariesTable _libraryIdTable(_$AppDatabase db) => db.libraries
      .createAlias($_aliasNameGenerator(db.notes.libraryId, db.libraries.id));

  $$LibrariesTableProcessedTableManager get libraryId {
    final $_column = $_itemColumn<String>('library_id')!;

    final manager = $$LibrariesTableTableManager(
      $_db,
      $_db.libraries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_libraryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ItemsTable _itemIdTable(_$AppDatabase db) =>
      db.items.createAlias($_aliasNameGenerator(db.notes.itemId, db.items.id));

  $$ItemsTableProcessedTableManager? get itemId {
    final $_column = $_itemColumn<String>('item_id');
    if ($_column == null) return null;
    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NotesTableFilterComposer extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  $$LibrariesTableFilterComposer get libraryId {
    final $$LibrariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableFilterComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibrariesTableOrderingComposer get libraryId {
    final $$LibrariesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableOrderingComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<double> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  $$LibrariesTableAnnotationComposer get libraryId {
    final $$LibrariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableAnnotationComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotesTable,
          Note,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (Note, $$NotesTableReferences),
          Note,
          PrefetchHooks Function({bool libraryId, bool itemId})
        > {
  $$NotesTableTableManager(_$AppDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> libraryId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<double?> positionSeconds = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                libraryId: libraryId,
                itemId: itemId,
                content: content,
                positionSeconds: positionSeconds,
                pageNumber: pageNumber,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                version: version,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String libraryId,
                Value<String?> itemId = const Value.absent(),
                required String content,
                Value<double?> positionSeconds = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                required String deviceId,
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                libraryId: libraryId,
                itemId: itemId,
                content: content,
                positionSeconds: positionSeconds,
                pageNumber: pageNumber,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                version: version,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$NotesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({libraryId = false, itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (libraryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.libraryId,
                                referencedTable: $$NotesTableReferences
                                    ._libraryIdTable(db),
                                referencedColumn: $$NotesTableReferences
                                    ._libraryIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$NotesTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$NotesTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotesTable,
      Note,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (Note, $$NotesTableReferences),
      Note,
      PrefetchHooks Function({bool libraryId, bool itemId})
    >;
typedef $$BookmarksTableCreateCompanionBuilder =
    BookmarksCompanion Function({
      required String id,
      required String libraryId,
      required String itemId,
      required String title,
      Value<String?> description,
      Value<double?> positionSeconds,
      Value<int?> pageNumber,
      required int createdAt,
      required int updatedAt,
      required String deviceId,
      Value<int> version,
      Value<bool> deleted,
      Value<int> rowid,
    });
typedef $$BookmarksTableUpdateCompanionBuilder =
    BookmarksCompanion Function({
      Value<String> id,
      Value<String> libraryId,
      Value<String> itemId,
      Value<String> title,
      Value<String?> description,
      Value<double?> positionSeconds,
      Value<int?> pageNumber,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String> deviceId,
      Value<int> version,
      Value<bool> deleted,
      Value<int> rowid,
    });

final class $$BookmarksTableReferences
    extends BaseReferences<_$AppDatabase, $BookmarksTable, Bookmark> {
  $$BookmarksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LibrariesTable _libraryIdTable(_$AppDatabase db) =>
      db.libraries.createAlias(
        $_aliasNameGenerator(db.bookmarks.libraryId, db.libraries.id),
      );

  $$LibrariesTableProcessedTableManager get libraryId {
    final $_column = $_itemColumn<String>('library_id')!;

    final manager = $$LibrariesTableTableManager(
      $_db,
      $_db.libraries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_libraryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ItemsTable _itemIdTable(_$AppDatabase db) => db.items.createAlias(
    $_aliasNameGenerator(db.bookmarks.itemId, db.items.id),
  );

  $$ItemsTableProcessedTableManager get itemId {
    final $_column = $_itemColumn<String>('item_id')!;

    final manager = $$ItemsTableTableManager(
      $_db,
      $_db.items,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_itemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  $$LibrariesTableFilterComposer get libraryId {
    final $$LibrariesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableFilterComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableFilterComposer get itemId {
    final $$ItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableFilterComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$LibrariesTableOrderingComposer get libraryId {
    final $$LibrariesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableOrderingComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableOrderingComposer get itemId {
    final $$ItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableOrderingComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $BookmarksTable> {
  $$BookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get positionSeconds => $composableBuilder(
    column: $table.positionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pageNumber => $composableBuilder(
    column: $table.pageNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  $$LibrariesTableAnnotationComposer get libraryId {
    final $$LibrariesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.libraryId,
      referencedTable: $db.libraries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LibrariesTableAnnotationComposer(
            $db: $db,
            $table: $db.libraries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ItemsTableAnnotationComposer get itemId {
    final $$ItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.itemId,
      referencedTable: $db.items,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.items,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BookmarksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookmarksTable,
          Bookmark,
          $$BookmarksTableFilterComposer,
          $$BookmarksTableOrderingComposer,
          $$BookmarksTableAnnotationComposer,
          $$BookmarksTableCreateCompanionBuilder,
          $$BookmarksTableUpdateCompanionBuilder,
          (Bookmark, $$BookmarksTableReferences),
          Bookmark,
          PrefetchHooks Function({bool libraryId, bool itemId})
        > {
  $$BookmarksTableTableManager(_$AppDatabase db, $BookmarksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> libraryId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double?> positionSeconds = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion(
                id: id,
                libraryId: libraryId,
                itemId: itemId,
                title: title,
                description: description,
                positionSeconds: positionSeconds,
                pageNumber: pageNumber,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                version: version,
                deleted: deleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String libraryId,
                required String itemId,
                required String title,
                Value<String?> description = const Value.absent(),
                Value<double?> positionSeconds = const Value.absent(),
                Value<int?> pageNumber = const Value.absent(),
                required int createdAt,
                required int updatedAt,
                required String deviceId,
                Value<int> version = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarksCompanion.insert(
                id: id,
                libraryId: libraryId,
                itemId: itemId,
                title: title,
                description: description,
                positionSeconds: positionSeconds,
                pageNumber: pageNumber,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deviceId: deviceId,
                version: version,
                deleted: deleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BookmarksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({libraryId = false, itemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (libraryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.libraryId,
                                referencedTable: $$BookmarksTableReferences
                                    ._libraryIdTable(db),
                                referencedColumn: $$BookmarksTableReferences
                                    ._libraryIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (itemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.itemId,
                                referencedTable: $$BookmarksTableReferences
                                    ._itemIdTable(db),
                                referencedColumn: $$BookmarksTableReferences
                                    ._itemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BookmarksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookmarksTable,
      Bookmark,
      $$BookmarksTableFilterComposer,
      $$BookmarksTableOrderingComposer,
      $$BookmarksTableAnnotationComposer,
      $$BookmarksTableCreateCompanionBuilder,
      $$BookmarksTableUpdateCompanionBuilder,
      (Bookmark, $$BookmarksTableReferences),
      Bookmark,
      PrefetchHooks Function({bool libraryId, bool itemId})
    >;
typedef $$KnownDevicesTableCreateCompanionBuilder =
    KnownDevicesCompanion Function({
      required String id,
      required String name,
      required String tokenHash,
      Value<bool> approved,
      required int createdAt,
      Value<int?> lastSeenAt,
      Value<int?> lastSyncAt,
      Value<String?> lastAddress,
      Value<bool> revoked,
      Value<int> version,
      Value<int> rowid,
    });
typedef $$KnownDevicesTableUpdateCompanionBuilder =
    KnownDevicesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> tokenHash,
      Value<bool> approved,
      Value<int> createdAt,
      Value<int?> lastSeenAt,
      Value<int?> lastSyncAt,
      Value<String?> lastAddress,
      Value<bool> revoked,
      Value<int> version,
      Value<int> rowid,
    });

class $$KnownDevicesTableFilterComposer
    extends Composer<_$AppDatabase, $KnownDevicesTable> {
  $$KnownDevicesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tokenHash => $composableBuilder(
    column: $table.tokenHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get approved => $composableBuilder(
    column: $table.approved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastAddress => $composableBuilder(
    column: $table.lastAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get revoked => $composableBuilder(
    column: $table.revoked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KnownDevicesTableOrderingComposer
    extends Composer<_$AppDatabase, $KnownDevicesTable> {
  $$KnownDevicesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tokenHash => $composableBuilder(
    column: $table.tokenHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get approved => $composableBuilder(
    column: $table.approved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastAddress => $composableBuilder(
    column: $table.lastAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get revoked => $composableBuilder(
    column: $table.revoked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KnownDevicesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KnownDevicesTable> {
  $$KnownDevicesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get tokenHash =>
      $composableBuilder(column: $table.tokenHash, builder: (column) => column);

  GeneratedColumn<bool> get approved =>
      $composableBuilder(column: $table.approved, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get lastSeenAt => $composableBuilder(
    column: $table.lastSeenAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastSyncAt => $composableBuilder(
    column: $table.lastSyncAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastAddress => $composableBuilder(
    column: $table.lastAddress,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get revoked =>
      $composableBuilder(column: $table.revoked, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);
}

class $$KnownDevicesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KnownDevicesTable,
          KnownDevice,
          $$KnownDevicesTableFilterComposer,
          $$KnownDevicesTableOrderingComposer,
          $$KnownDevicesTableAnnotationComposer,
          $$KnownDevicesTableCreateCompanionBuilder,
          $$KnownDevicesTableUpdateCompanionBuilder,
          (
            KnownDevice,
            BaseReferences<_$AppDatabase, $KnownDevicesTable, KnownDevice>,
          ),
          KnownDevice,
          PrefetchHooks Function()
        > {
  $$KnownDevicesTableTableManager(_$AppDatabase db, $KnownDevicesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KnownDevicesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KnownDevicesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KnownDevicesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> tokenHash = const Value.absent(),
                Value<bool> approved = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> lastSyncAt = const Value.absent(),
                Value<String?> lastAddress = const Value.absent(),
                Value<bool> revoked = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KnownDevicesCompanion(
                id: id,
                name: name,
                tokenHash: tokenHash,
                approved: approved,
                createdAt: createdAt,
                lastSeenAt: lastSeenAt,
                lastSyncAt: lastSyncAt,
                lastAddress: lastAddress,
                revoked: revoked,
                version: version,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String tokenHash,
                Value<bool> approved = const Value.absent(),
                required int createdAt,
                Value<int?> lastSeenAt = const Value.absent(),
                Value<int?> lastSyncAt = const Value.absent(),
                Value<String?> lastAddress = const Value.absent(),
                Value<bool> revoked = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KnownDevicesCompanion.insert(
                id: id,
                name: name,
                tokenHash: tokenHash,
                approved: approved,
                createdAt: createdAt,
                lastSeenAt: lastSeenAt,
                lastSyncAt: lastSyncAt,
                lastAddress: lastAddress,
                revoked: revoked,
                version: version,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KnownDevicesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KnownDevicesTable,
      KnownDevice,
      $$KnownDevicesTableFilterComposer,
      $$KnownDevicesTableOrderingComposer,
      $$KnownDevicesTableAnnotationComposer,
      $$KnownDevicesTableCreateCompanionBuilder,
      $$KnownDevicesTableUpdateCompanionBuilder,
      (
        KnownDevice,
        BaseReferences<_$AppDatabase, $KnownDevicesTable, KnownDevice>,
      ),
      KnownDevice,
      PrefetchHooks Function()
    >;
typedef $$SyncChangesTableCreateCompanionBuilder =
    SyncChangesCompanion Function({
      required String id,
      required String entityType,
      required String entityId,
      required String operation,
      required String payload,
      required int version,
      required String deviceId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$SyncChangesTableUpdateCompanionBuilder =
    SyncChangesCompanion Function({
      Value<String> id,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> operation,
      Value<String> payload,
      Value<int> version,
      Value<String> deviceId,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$SyncChangesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncChangesTable> {
  $$SyncChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncChangesTable> {
  $$SyncChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncChangesTable> {
  $$SyncChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncChangesTable,
          SyncChange,
          $$SyncChangesTableFilterComposer,
          $$SyncChangesTableOrderingComposer,
          $$SyncChangesTableAnnotationComposer,
          $$SyncChangesTableCreateCompanionBuilder,
          $$SyncChangesTableUpdateCompanionBuilder,
          (
            SyncChange,
            BaseReferences<_$AppDatabase, $SyncChangesTable, SyncChange>,
          ),
          SyncChange,
          PrefetchHooks Function()
        > {
  $$SyncChangesTableTableManager(_$AppDatabase db, $SyncChangesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncChangesCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payload: payload,
                version: version,
                deviceId: deviceId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String entityType,
                required String entityId,
                required String operation,
                required String payload,
                required int version,
                required String deviceId,
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncChangesCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payload: payload,
                version: version,
                deviceId: deviceId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncChangesTable,
      SyncChange,
      $$SyncChangesTableFilterComposer,
      $$SyncChangesTableOrderingComposer,
      $$SyncChangesTableAnnotationComposer,
      $$SyncChangesTableCreateCompanionBuilder,
      $$SyncChangesTableUpdateCompanionBuilder,
      (
        SyncChange,
        BaseReferences<_$AppDatabase, $SyncChangesTable, SyncChange>,
      ),
      SyncChange,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LibrariesTableTableManager get libraries =>
      $$LibrariesTableTableManager(_db, _db.libraries);
  $$SectionsTableTableManager get sections =>
      $$SectionsTableTableManager(_db, _db.sections);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$PlaybackProgressTableTableManager get playbackProgress =>
      $$PlaybackProgressTableTableManager(_db, _db.playbackProgress);
  $$ReadingProgressTableTableManager get readingProgress =>
      $$ReadingProgressTableTableManager(_db, _db.readingProgress);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$BookmarksTableTableManager get bookmarks =>
      $$BookmarksTableTableManager(_db, _db.bookmarks);
  $$KnownDevicesTableTableManager get knownDevices =>
      $$KnownDevicesTableTableManager(_db, _db.knownDevices);
  $$SyncChangesTableTableManager get syncChanges =>
      $$SyncChangesTableTableManager(_db, _db.syncChanges);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
