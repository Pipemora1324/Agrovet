// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CowsTable extends Cows with TableInfo<$CowsTable, CowRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
  static const VerificationMeta _syncPendingMeta = const VerificationMeta(
    'syncPending',
  );
  @override
  late final GeneratedColumn<bool> syncPending = GeneratedColumn<bool>(
    'sync_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDemoMeta = const VerificationMeta('isDemo');
  @override
  late final GeneratedColumn<bool> isDemo = GeneratedColumn<bool>(
    'is_demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 40,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _breedMeta = const VerificationMeta('breed');
  @override
  late final GeneratedColumn<String> breed = GeneratedColumn<String>(
    'breed',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<DateTime> birthDate = GeneratedColumn<DateTime>(
    'birth_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _calvingsMeta = const VerificationMeta(
    'calvings',
  );
  @override
  late final GeneratedColumn<int> calvings = GeneratedColumn<int>(
    'calvings',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productionStatusMeta = const VerificationMeta(
    'productionStatus',
  );
  @override
  late final GeneratedColumn<String> productionStatus = GeneratedColumn<String>(
    'production_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    syncPending,
    isDemo,
    syncError,
    id,
    tag,
    name,
    breed,
    birthDate,
    calvings,
    productionStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cows';
  @override
  VerificationContext validateIntegrity(
    Insertable<CowRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('sync_pending')) {
      context.handle(
        _syncPendingMeta,
        syncPending.isAcceptableOrUnknown(
          data['sync_pending']!,
          _syncPendingMeta,
        ),
      );
    }
    if (data.containsKey('is_demo')) {
      context.handle(
        _isDemoMeta,
        isDemo.isAcceptableOrUnknown(data['is_demo']!, _isDemoMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('breed')) {
      context.handle(
        _breedMeta,
        breed.isAcceptableOrUnknown(data['breed']!, _breedMeta),
      );
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    }
    if (data.containsKey('calvings')) {
      context.handle(
        _calvingsMeta,
        calvings.isAcceptableOrUnknown(data['calvings']!, _calvingsMeta),
      );
    }
    if (data.containsKey('production_status')) {
      context.handle(
        _productionStatusMeta,
        productionStatus.isAcceptableOrUnknown(
          data['production_status']!,
          _productionStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productionStatusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CowRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CowRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      syncPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_pending'],
      )!,
      isDemo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_demo'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      ),
      breed: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}breed'],
      ),
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birth_date'],
      ),
      calvings: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calvings'],
      ),
      productionStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}production_status'],
      )!,
    );
  }

  @override
  $CowsTable createAlias(String alias) {
    return $CowsTable(attachedDatabase, alias);
  }
}

class CowRow extends DataClass implements Insertable<CowRow> {
  final DateTime updatedAt;
  final bool deleted;
  final bool syncPending;

  /// Datos de demostración (solo en modo debug); nunca se sincronizan.
  final bool isDemo;

  /// Motivo por el que el servidor rechazó el elemento (no se reintenta hasta que cambie).
  final String? syncError;
  final String id;
  final String tag;
  final String? name;
  final String? breed;
  final DateTime? birthDate;
  final int? calvings;
  final String productionStatus;
  const CowRow({
    required this.updatedAt,
    required this.deleted,
    required this.syncPending,
    required this.isDemo,
    this.syncError,
    required this.id,
    required this.tag,
    this.name,
    this.breed,
    this.birthDate,
    this.calvings,
    required this.productionStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['sync_pending'] = Variable<bool>(syncPending);
    map['is_demo'] = Variable<bool>(isDemo);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['id'] = Variable<String>(id);
    map['tag'] = Variable<String>(tag);
    if (!nullToAbsent || name != null) {
      map['name'] = Variable<String>(name);
    }
    if (!nullToAbsent || breed != null) {
      map['breed'] = Variable<String>(breed);
    }
    if (!nullToAbsent || birthDate != null) {
      map['birth_date'] = Variable<DateTime>(birthDate);
    }
    if (!nullToAbsent || calvings != null) {
      map['calvings'] = Variable<int>(calvings);
    }
    map['production_status'] = Variable<String>(productionStatus);
    return map;
  }

  CowsCompanion toCompanion(bool nullToAbsent) {
    return CowsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      syncPending: Value(syncPending),
      isDemo: Value(isDemo),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      id: Value(id),
      tag: Value(tag),
      name: name == null && nullToAbsent ? const Value.absent() : Value(name),
      breed: breed == null && nullToAbsent
          ? const Value.absent()
          : Value(breed),
      birthDate: birthDate == null && nullToAbsent
          ? const Value.absent()
          : Value(birthDate),
      calvings: calvings == null && nullToAbsent
          ? const Value.absent()
          : Value(calvings),
      productionStatus: Value(productionStatus),
    );
  }

  factory CowRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CowRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      syncPending: serializer.fromJson<bool>(json['syncPending']),
      isDemo: serializer.fromJson<bool>(json['isDemo']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      id: serializer.fromJson<String>(json['id']),
      tag: serializer.fromJson<String>(json['tag']),
      name: serializer.fromJson<String?>(json['name']),
      breed: serializer.fromJson<String?>(json['breed']),
      birthDate: serializer.fromJson<DateTime?>(json['birthDate']),
      calvings: serializer.fromJson<int?>(json['calvings']),
      productionStatus: serializer.fromJson<String>(json['productionStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'syncPending': serializer.toJson<bool>(syncPending),
      'isDemo': serializer.toJson<bool>(isDemo),
      'syncError': serializer.toJson<String?>(syncError),
      'id': serializer.toJson<String>(id),
      'tag': serializer.toJson<String>(tag),
      'name': serializer.toJson<String?>(name),
      'breed': serializer.toJson<String?>(breed),
      'birthDate': serializer.toJson<DateTime?>(birthDate),
      'calvings': serializer.toJson<int?>(calvings),
      'productionStatus': serializer.toJson<String>(productionStatus),
    };
  }

  CowRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? syncPending,
    bool? isDemo,
    Value<String?> syncError = const Value.absent(),
    String? id,
    String? tag,
    Value<String?> name = const Value.absent(),
    Value<String?> breed = const Value.absent(),
    Value<DateTime?> birthDate = const Value.absent(),
    Value<int?> calvings = const Value.absent(),
    String? productionStatus,
  }) => CowRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    syncPending: syncPending ?? this.syncPending,
    isDemo: isDemo ?? this.isDemo,
    syncError: syncError.present ? syncError.value : this.syncError,
    id: id ?? this.id,
    tag: tag ?? this.tag,
    name: name.present ? name.value : this.name,
    breed: breed.present ? breed.value : this.breed,
    birthDate: birthDate.present ? birthDate.value : this.birthDate,
    calvings: calvings.present ? calvings.value : this.calvings,
    productionStatus: productionStatus ?? this.productionStatus,
  );
  CowRow copyWithCompanion(CowsCompanion data) {
    return CowRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      syncPending: data.syncPending.present
          ? data.syncPending.value
          : this.syncPending,
      isDemo: data.isDemo.present ? data.isDemo.value : this.isDemo,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      id: data.id.present ? data.id.value : this.id,
      tag: data.tag.present ? data.tag.value : this.tag,
      name: data.name.present ? data.name.value : this.name,
      breed: data.breed.present ? data.breed.value : this.breed,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      calvings: data.calvings.present ? data.calvings.value : this.calvings,
      productionStatus: data.productionStatus.present
          ? data.productionStatus.value
          : this.productionStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CowRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('syncPending: $syncPending, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncError: $syncError, ')
          ..write('id: $id, ')
          ..write('tag: $tag, ')
          ..write('name: $name, ')
          ..write('breed: $breed, ')
          ..write('birthDate: $birthDate, ')
          ..write('calvings: $calvings, ')
          ..write('productionStatus: $productionStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deleted,
    syncPending,
    isDemo,
    syncError,
    id,
    tag,
    name,
    breed,
    birthDate,
    calvings,
    productionStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CowRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.syncPending == this.syncPending &&
          other.isDemo == this.isDemo &&
          other.syncError == this.syncError &&
          other.id == this.id &&
          other.tag == this.tag &&
          other.name == this.name &&
          other.breed == this.breed &&
          other.birthDate == this.birthDate &&
          other.calvings == this.calvings &&
          other.productionStatus == this.productionStatus);
}

class CowsCompanion extends UpdateCompanion<CowRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> syncPending;
  final Value<bool> isDemo;
  final Value<String?> syncError;
  final Value<String> id;
  final Value<String> tag;
  final Value<String?> name;
  final Value<String?> breed;
  final Value<DateTime?> birthDate;
  final Value<int?> calvings;
  final Value<String> productionStatus;
  final Value<int> rowid;
  const CowsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncError = const Value.absent(),
    this.id = const Value.absent(),
    this.tag = const Value.absent(),
    this.name = const Value.absent(),
    this.breed = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.calvings = const Value.absent(),
    this.productionStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CowsCompanion.insert({
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncError = const Value.absent(),
    required String id,
    required String tag,
    this.name = const Value.absent(),
    this.breed = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.calvings = const Value.absent(),
    required String productionStatus,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       tag = Value(tag),
       productionStatus = Value(productionStatus);
  static Insertable<CowRow> custom({
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? syncPending,
    Expression<bool>? isDemo,
    Expression<String>? syncError,
    Expression<String>? id,
    Expression<String>? tag,
    Expression<String>? name,
    Expression<String>? breed,
    Expression<DateTime>? birthDate,
    Expression<int>? calvings,
    Expression<String>? productionStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (syncPending != null) 'sync_pending': syncPending,
      if (isDemo != null) 'is_demo': isDemo,
      if (syncError != null) 'sync_error': syncError,
      if (id != null) 'id': id,
      if (tag != null) 'tag': tag,
      if (name != null) 'name': name,
      if (breed != null) 'breed': breed,
      if (birthDate != null) 'birth_date': birthDate,
      if (calvings != null) 'calvings': calvings,
      if (productionStatus != null) 'production_status': productionStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CowsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? syncPending,
    Value<bool>? isDemo,
    Value<String?>? syncError,
    Value<String>? id,
    Value<String>? tag,
    Value<String?>? name,
    Value<String?>? breed,
    Value<DateTime?>? birthDate,
    Value<int?>? calvings,
    Value<String>? productionStatus,
    Value<int>? rowid,
  }) {
    return CowsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      syncPending: syncPending ?? this.syncPending,
      isDemo: isDemo ?? this.isDemo,
      syncError: syncError ?? this.syncError,
      id: id ?? this.id,
      tag: tag ?? this.tag,
      name: name ?? this.name,
      breed: breed ?? this.breed,
      birthDate: birthDate ?? this.birthDate,
      calvings: calvings ?? this.calvings,
      productionStatus: productionStatus ?? this.productionStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (syncPending.present) {
      map['sync_pending'] = Variable<bool>(syncPending.value);
    }
    if (isDemo.present) {
      map['is_demo'] = Variable<bool>(isDemo.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (breed.present) {
      map['breed'] = Variable<String>(breed.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<DateTime>(birthDate.value);
    }
    if (calvings.present) {
      map['calvings'] = Variable<int>(calvings.value);
    }
    if (productionStatus.present) {
      map['production_status'] = Variable<String>(productionStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CowsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('syncPending: $syncPending, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncError: $syncError, ')
          ..write('id: $id, ')
          ..write('tag: $tag, ')
          ..write('name: $name, ')
          ..write('breed: $breed, ')
          ..write('birthDate: $birthDate, ')
          ..write('calvings: $calvings, ')
          ..write('productionStatus: $productionStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyRecordsTable extends DailyRecords
    with TableInfo<$DailyRecordsTable, DailyRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
  static const VerificationMeta _syncPendingMeta = const VerificationMeta(
    'syncPending',
  );
  @override
  late final GeneratedColumn<bool> syncPending = GeneratedColumn<bool>(
    'sync_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDemoMeta = const VerificationMeta('isDemo');
  @override
  late final GeneratedColumn<bool> isDemo = GeneratedColumn<bool>(
    'is_demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cowIdMeta = const VerificationMeta('cowId');
  @override
  late final GeneratedColumn<String> cowId = GeneratedColumn<String>(
    'cow_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cows (id)',
    ),
  );
  static const VerificationMeta _recordDateMeta = const VerificationMeta(
    'recordDate',
  );
  @override
  late final GeneratedColumn<String> recordDate = GeneratedColumn<String>(
    'record_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _temperatureCMeta = const VerificationMeta(
    'temperatureC',
  );
  @override
  late final GeneratedColumn<double> temperatureC = GeneratedColumn<double>(
    'temperature_c',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _milkLMeta = const VerificationMeta('milkL');
  @override
  late final GeneratedColumn<double> milkL = GeneratedColumn<double>(
    'milk_l',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _feedKgMeta = const VerificationMeta('feedKg');
  @override
  late final GeneratedColumn<double> feedKg = GeneratedColumn<double>(
    'feed_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _udderSwellingMeta = const VerificationMeta(
    'udderSwelling',
  );
  @override
  late final GeneratedColumn<bool> udderSwelling = GeneratedColumn<bool>(
    'udder_swelling',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("udder_swelling" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _abnormalMilkMeta = const VerificationMeta(
    'abnormalMilk',
  );
  @override
  late final GeneratedColumn<bool> abnormalMilk = GeneratedColumn<bool>(
    'abnormal_milk',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("abnormal_milk" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _udderPainMeta = const VerificationMeta(
    'udderPain',
  );
  @override
  late final GeneratedColumn<bool> udderPain = GeneratedColumn<bool>(
    'udder_pain',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("udder_pain" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lethargyMeta = const VerificationMeta(
    'lethargy',
  );
  @override
  late final GeneratedColumn<bool> lethargy = GeneratedColumn<bool>(
    'lethargy',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("lethargy" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _udderRednessMeta = const VerificationMeta(
    'udderRedness',
  );
  @override
  late final GeneratedColumn<bool> udderRedness = GeneratedColumn<bool>(
    'udder_redness',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("udder_redness" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _udderHeatMeta = const VerificationMeta(
    'udderHeat',
  );
  @override
  late final GeneratedColumn<bool> udderHeat = GeneratedColumn<bool>(
    'udder_heat',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("udder_heat" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _ateNormallyMeta = const VerificationMeta(
    'ateNormally',
  );
  @override
  late final GeneratedColumn<bool> ateNormally = GeneratedColumn<bool>(
    'ate_normally',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("ate_normally" IN (0, 1))',
    ),
  );
  static const VerificationMeta _milkDropMeta = const VerificationMeta(
    'milkDrop',
  );
  @override
  late final GeneratedColumn<bool> milkDrop = GeneratedColumn<bool>(
    'milk_drop',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("milk_drop" IN (0, 1))',
    ),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    syncPending,
    isDemo,
    syncError,
    id,
    cowId,
    recordDate,
    temperatureC,
    milkL,
    feedKg,
    udderSwelling,
    abnormalMilk,
    udderPain,
    lethargy,
    udderRedness,
    udderHeat,
    ateNormally,
    milkDrop,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('sync_pending')) {
      context.handle(
        _syncPendingMeta,
        syncPending.isAcceptableOrUnknown(
          data['sync_pending']!,
          _syncPendingMeta,
        ),
      );
    }
    if (data.containsKey('is_demo')) {
      context.handle(
        _isDemoMeta,
        isDemo.isAcceptableOrUnknown(data['is_demo']!, _isDemoMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cow_id')) {
      context.handle(
        _cowIdMeta,
        cowId.isAcceptableOrUnknown(data['cow_id']!, _cowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cowIdMeta);
    }
    if (data.containsKey('record_date')) {
      context.handle(
        _recordDateMeta,
        recordDate.isAcceptableOrUnknown(data['record_date']!, _recordDateMeta),
      );
    } else if (isInserting) {
      context.missing(_recordDateMeta);
    }
    if (data.containsKey('temperature_c')) {
      context.handle(
        _temperatureCMeta,
        temperatureC.isAcceptableOrUnknown(
          data['temperature_c']!,
          _temperatureCMeta,
        ),
      );
    }
    if (data.containsKey('milk_l')) {
      context.handle(
        _milkLMeta,
        milkL.isAcceptableOrUnknown(data['milk_l']!, _milkLMeta),
      );
    }
    if (data.containsKey('feed_kg')) {
      context.handle(
        _feedKgMeta,
        feedKg.isAcceptableOrUnknown(data['feed_kg']!, _feedKgMeta),
      );
    }
    if (data.containsKey('udder_swelling')) {
      context.handle(
        _udderSwellingMeta,
        udderSwelling.isAcceptableOrUnknown(
          data['udder_swelling']!,
          _udderSwellingMeta,
        ),
      );
    }
    if (data.containsKey('abnormal_milk')) {
      context.handle(
        _abnormalMilkMeta,
        abnormalMilk.isAcceptableOrUnknown(
          data['abnormal_milk']!,
          _abnormalMilkMeta,
        ),
      );
    }
    if (data.containsKey('udder_pain')) {
      context.handle(
        _udderPainMeta,
        udderPain.isAcceptableOrUnknown(data['udder_pain']!, _udderPainMeta),
      );
    }
    if (data.containsKey('lethargy')) {
      context.handle(
        _lethargyMeta,
        lethargy.isAcceptableOrUnknown(data['lethargy']!, _lethargyMeta),
      );
    }
    if (data.containsKey('udder_redness')) {
      context.handle(
        _udderRednessMeta,
        udderRedness.isAcceptableOrUnknown(
          data['udder_redness']!,
          _udderRednessMeta,
        ),
      );
    }
    if (data.containsKey('udder_heat')) {
      context.handle(
        _udderHeatMeta,
        udderHeat.isAcceptableOrUnknown(data['udder_heat']!, _udderHeatMeta),
      );
    }
    if (data.containsKey('ate_normally')) {
      context.handle(
        _ateNormallyMeta,
        ateNormally.isAcceptableOrUnknown(
          data['ate_normally']!,
          _ateNormallyMeta,
        ),
      );
    }
    if (data.containsKey('milk_drop')) {
      context.handle(
        _milkDropMeta,
        milkDrop.isAcceptableOrUnknown(data['milk_drop']!, _milkDropMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {cowId, recordDate},
  ];
  @override
  DailyRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyRecordRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      syncPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_pending'],
      )!,
      isDemo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_demo'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cow_id'],
      )!,
      recordDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_date'],
      )!,
      temperatureC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}temperature_c'],
      ),
      milkL: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}milk_l'],
      ),
      feedKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}feed_kg'],
      ),
      udderSwelling: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}udder_swelling'],
      )!,
      abnormalMilk: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}abnormal_milk'],
      )!,
      udderPain: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}udder_pain'],
      )!,
      lethargy: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}lethargy'],
      )!,
      udderRedness: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}udder_redness'],
      )!,
      udderHeat: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}udder_heat'],
      )!,
      ateNormally: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ate_normally'],
      ),
      milkDrop: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}milk_drop'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $DailyRecordsTable createAlias(String alias) {
    return $DailyRecordsTable(attachedDatabase, alias);
  }
}

class DailyRecordRow extends DataClass implements Insertable<DailyRecordRow> {
  final DateTime updatedAt;
  final bool deleted;
  final bool syncPending;

  /// Datos de demostración (solo en modo debug); nunca se sincronizan.
  final bool isDemo;

  /// Motivo por el que el servidor rechazó el elemento (no se reintenta hasta que cambie).
  final String? syncError;
  final String id;
  final String cowId;

  /// Fecha del registro como texto AAAA-MM-DD.
  final String recordDate;
  final double? temperatureC;
  final double? milkL;
  final double? feedKg;
  final bool udderSwelling;
  final bool abnormalMilk;
  final bool udderPain;

  /// Casilla de versiones anteriores ("decaída, come poco"); ya no se pregunta pero se conserva.
  final bool lethargy;
  final bool udderRedness;
  final bool udderHeat;

  /// ¿Comió normal? null = sin respuesta.
  final bool? ateNormally;

  /// ¿Produjo menos leche de lo usual? null = sin respuesta.
  final bool? milkDrop;
  final String? notes;
  const DailyRecordRow({
    required this.updatedAt,
    required this.deleted,
    required this.syncPending,
    required this.isDemo,
    this.syncError,
    required this.id,
    required this.cowId,
    required this.recordDate,
    this.temperatureC,
    this.milkL,
    this.feedKg,
    required this.udderSwelling,
    required this.abnormalMilk,
    required this.udderPain,
    required this.lethargy,
    required this.udderRedness,
    required this.udderHeat,
    this.ateNormally,
    this.milkDrop,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['sync_pending'] = Variable<bool>(syncPending);
    map['is_demo'] = Variable<bool>(isDemo);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['id'] = Variable<String>(id);
    map['cow_id'] = Variable<String>(cowId);
    map['record_date'] = Variable<String>(recordDate);
    if (!nullToAbsent || temperatureC != null) {
      map['temperature_c'] = Variable<double>(temperatureC);
    }
    if (!nullToAbsent || milkL != null) {
      map['milk_l'] = Variable<double>(milkL);
    }
    if (!nullToAbsent || feedKg != null) {
      map['feed_kg'] = Variable<double>(feedKg);
    }
    map['udder_swelling'] = Variable<bool>(udderSwelling);
    map['abnormal_milk'] = Variable<bool>(abnormalMilk);
    map['udder_pain'] = Variable<bool>(udderPain);
    map['lethargy'] = Variable<bool>(lethargy);
    map['udder_redness'] = Variable<bool>(udderRedness);
    map['udder_heat'] = Variable<bool>(udderHeat);
    if (!nullToAbsent || ateNormally != null) {
      map['ate_normally'] = Variable<bool>(ateNormally);
    }
    if (!nullToAbsent || milkDrop != null) {
      map['milk_drop'] = Variable<bool>(milkDrop);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  DailyRecordsCompanion toCompanion(bool nullToAbsent) {
    return DailyRecordsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      syncPending: Value(syncPending),
      isDemo: Value(isDemo),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      id: Value(id),
      cowId: Value(cowId),
      recordDate: Value(recordDate),
      temperatureC: temperatureC == null && nullToAbsent
          ? const Value.absent()
          : Value(temperatureC),
      milkL: milkL == null && nullToAbsent
          ? const Value.absent()
          : Value(milkL),
      feedKg: feedKg == null && nullToAbsent
          ? const Value.absent()
          : Value(feedKg),
      udderSwelling: Value(udderSwelling),
      abnormalMilk: Value(abnormalMilk),
      udderPain: Value(udderPain),
      lethargy: Value(lethargy),
      udderRedness: Value(udderRedness),
      udderHeat: Value(udderHeat),
      ateNormally: ateNormally == null && nullToAbsent
          ? const Value.absent()
          : Value(ateNormally),
      milkDrop: milkDrop == null && nullToAbsent
          ? const Value.absent()
          : Value(milkDrop),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory DailyRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyRecordRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      syncPending: serializer.fromJson<bool>(json['syncPending']),
      isDemo: serializer.fromJson<bool>(json['isDemo']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      id: serializer.fromJson<String>(json['id']),
      cowId: serializer.fromJson<String>(json['cowId']),
      recordDate: serializer.fromJson<String>(json['recordDate']),
      temperatureC: serializer.fromJson<double?>(json['temperatureC']),
      milkL: serializer.fromJson<double?>(json['milkL']),
      feedKg: serializer.fromJson<double?>(json['feedKg']),
      udderSwelling: serializer.fromJson<bool>(json['udderSwelling']),
      abnormalMilk: serializer.fromJson<bool>(json['abnormalMilk']),
      udderPain: serializer.fromJson<bool>(json['udderPain']),
      lethargy: serializer.fromJson<bool>(json['lethargy']),
      udderRedness: serializer.fromJson<bool>(json['udderRedness']),
      udderHeat: serializer.fromJson<bool>(json['udderHeat']),
      ateNormally: serializer.fromJson<bool?>(json['ateNormally']),
      milkDrop: serializer.fromJson<bool?>(json['milkDrop']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'syncPending': serializer.toJson<bool>(syncPending),
      'isDemo': serializer.toJson<bool>(isDemo),
      'syncError': serializer.toJson<String?>(syncError),
      'id': serializer.toJson<String>(id),
      'cowId': serializer.toJson<String>(cowId),
      'recordDate': serializer.toJson<String>(recordDate),
      'temperatureC': serializer.toJson<double?>(temperatureC),
      'milkL': serializer.toJson<double?>(milkL),
      'feedKg': serializer.toJson<double?>(feedKg),
      'udderSwelling': serializer.toJson<bool>(udderSwelling),
      'abnormalMilk': serializer.toJson<bool>(abnormalMilk),
      'udderPain': serializer.toJson<bool>(udderPain),
      'lethargy': serializer.toJson<bool>(lethargy),
      'udderRedness': serializer.toJson<bool>(udderRedness),
      'udderHeat': serializer.toJson<bool>(udderHeat),
      'ateNormally': serializer.toJson<bool?>(ateNormally),
      'milkDrop': serializer.toJson<bool?>(milkDrop),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  DailyRecordRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? syncPending,
    bool? isDemo,
    Value<String?> syncError = const Value.absent(),
    String? id,
    String? cowId,
    String? recordDate,
    Value<double?> temperatureC = const Value.absent(),
    Value<double?> milkL = const Value.absent(),
    Value<double?> feedKg = const Value.absent(),
    bool? udderSwelling,
    bool? abnormalMilk,
    bool? udderPain,
    bool? lethargy,
    bool? udderRedness,
    bool? udderHeat,
    Value<bool?> ateNormally = const Value.absent(),
    Value<bool?> milkDrop = const Value.absent(),
    Value<String?> notes = const Value.absent(),
  }) => DailyRecordRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    syncPending: syncPending ?? this.syncPending,
    isDemo: isDemo ?? this.isDemo,
    syncError: syncError.present ? syncError.value : this.syncError,
    id: id ?? this.id,
    cowId: cowId ?? this.cowId,
    recordDate: recordDate ?? this.recordDate,
    temperatureC: temperatureC.present ? temperatureC.value : this.temperatureC,
    milkL: milkL.present ? milkL.value : this.milkL,
    feedKg: feedKg.present ? feedKg.value : this.feedKg,
    udderSwelling: udderSwelling ?? this.udderSwelling,
    abnormalMilk: abnormalMilk ?? this.abnormalMilk,
    udderPain: udderPain ?? this.udderPain,
    lethargy: lethargy ?? this.lethargy,
    udderRedness: udderRedness ?? this.udderRedness,
    udderHeat: udderHeat ?? this.udderHeat,
    ateNormally: ateNormally.present ? ateNormally.value : this.ateNormally,
    milkDrop: milkDrop.present ? milkDrop.value : this.milkDrop,
    notes: notes.present ? notes.value : this.notes,
  );
  DailyRecordRow copyWithCompanion(DailyRecordsCompanion data) {
    return DailyRecordRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      syncPending: data.syncPending.present
          ? data.syncPending.value
          : this.syncPending,
      isDemo: data.isDemo.present ? data.isDemo.value : this.isDemo,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      id: data.id.present ? data.id.value : this.id,
      cowId: data.cowId.present ? data.cowId.value : this.cowId,
      recordDate: data.recordDate.present
          ? data.recordDate.value
          : this.recordDate,
      temperatureC: data.temperatureC.present
          ? data.temperatureC.value
          : this.temperatureC,
      milkL: data.milkL.present ? data.milkL.value : this.milkL,
      feedKg: data.feedKg.present ? data.feedKg.value : this.feedKg,
      udderSwelling: data.udderSwelling.present
          ? data.udderSwelling.value
          : this.udderSwelling,
      abnormalMilk: data.abnormalMilk.present
          ? data.abnormalMilk.value
          : this.abnormalMilk,
      udderPain: data.udderPain.present ? data.udderPain.value : this.udderPain,
      lethargy: data.lethargy.present ? data.lethargy.value : this.lethargy,
      udderRedness: data.udderRedness.present
          ? data.udderRedness.value
          : this.udderRedness,
      udderHeat: data.udderHeat.present ? data.udderHeat.value : this.udderHeat,
      ateNormally: data.ateNormally.present
          ? data.ateNormally.value
          : this.ateNormally,
      milkDrop: data.milkDrop.present ? data.milkDrop.value : this.milkDrop,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyRecordRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('syncPending: $syncPending, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncError: $syncError, ')
          ..write('id: $id, ')
          ..write('cowId: $cowId, ')
          ..write('recordDate: $recordDate, ')
          ..write('temperatureC: $temperatureC, ')
          ..write('milkL: $milkL, ')
          ..write('feedKg: $feedKg, ')
          ..write('udderSwelling: $udderSwelling, ')
          ..write('abnormalMilk: $abnormalMilk, ')
          ..write('udderPain: $udderPain, ')
          ..write('lethargy: $lethargy, ')
          ..write('udderRedness: $udderRedness, ')
          ..write('udderHeat: $udderHeat, ')
          ..write('ateNormally: $ateNormally, ')
          ..write('milkDrop: $milkDrop, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deleted,
    syncPending,
    isDemo,
    syncError,
    id,
    cowId,
    recordDate,
    temperatureC,
    milkL,
    feedKg,
    udderSwelling,
    abnormalMilk,
    udderPain,
    lethargy,
    udderRedness,
    udderHeat,
    ateNormally,
    milkDrop,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyRecordRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.syncPending == this.syncPending &&
          other.isDemo == this.isDemo &&
          other.syncError == this.syncError &&
          other.id == this.id &&
          other.cowId == this.cowId &&
          other.recordDate == this.recordDate &&
          other.temperatureC == this.temperatureC &&
          other.milkL == this.milkL &&
          other.feedKg == this.feedKg &&
          other.udderSwelling == this.udderSwelling &&
          other.abnormalMilk == this.abnormalMilk &&
          other.udderPain == this.udderPain &&
          other.lethargy == this.lethargy &&
          other.udderRedness == this.udderRedness &&
          other.udderHeat == this.udderHeat &&
          other.ateNormally == this.ateNormally &&
          other.milkDrop == this.milkDrop &&
          other.notes == this.notes);
}

class DailyRecordsCompanion extends UpdateCompanion<DailyRecordRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> syncPending;
  final Value<bool> isDemo;
  final Value<String?> syncError;
  final Value<String> id;
  final Value<String> cowId;
  final Value<String> recordDate;
  final Value<double?> temperatureC;
  final Value<double?> milkL;
  final Value<double?> feedKg;
  final Value<bool> udderSwelling;
  final Value<bool> abnormalMilk;
  final Value<bool> udderPain;
  final Value<bool> lethargy;
  final Value<bool> udderRedness;
  final Value<bool> udderHeat;
  final Value<bool?> ateNormally;
  final Value<bool?> milkDrop;
  final Value<String?> notes;
  final Value<int> rowid;
  const DailyRecordsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncError = const Value.absent(),
    this.id = const Value.absent(),
    this.cowId = const Value.absent(),
    this.recordDate = const Value.absent(),
    this.temperatureC = const Value.absent(),
    this.milkL = const Value.absent(),
    this.feedKg = const Value.absent(),
    this.udderSwelling = const Value.absent(),
    this.abnormalMilk = const Value.absent(),
    this.udderPain = const Value.absent(),
    this.lethargy = const Value.absent(),
    this.udderRedness = const Value.absent(),
    this.udderHeat = const Value.absent(),
    this.ateNormally = const Value.absent(),
    this.milkDrop = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyRecordsCompanion.insert({
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncError = const Value.absent(),
    required String id,
    required String cowId,
    required String recordDate,
    this.temperatureC = const Value.absent(),
    this.milkL = const Value.absent(),
    this.feedKg = const Value.absent(),
    this.udderSwelling = const Value.absent(),
    this.abnormalMilk = const Value.absent(),
    this.udderPain = const Value.absent(),
    this.lethargy = const Value.absent(),
    this.udderRedness = const Value.absent(),
    this.udderHeat = const Value.absent(),
    this.ateNormally = const Value.absent(),
    this.milkDrop = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       cowId = Value(cowId),
       recordDate = Value(recordDate);
  static Insertable<DailyRecordRow> custom({
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? syncPending,
    Expression<bool>? isDemo,
    Expression<String>? syncError,
    Expression<String>? id,
    Expression<String>? cowId,
    Expression<String>? recordDate,
    Expression<double>? temperatureC,
    Expression<double>? milkL,
    Expression<double>? feedKg,
    Expression<bool>? udderSwelling,
    Expression<bool>? abnormalMilk,
    Expression<bool>? udderPain,
    Expression<bool>? lethargy,
    Expression<bool>? udderRedness,
    Expression<bool>? udderHeat,
    Expression<bool>? ateNormally,
    Expression<bool>? milkDrop,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (syncPending != null) 'sync_pending': syncPending,
      if (isDemo != null) 'is_demo': isDemo,
      if (syncError != null) 'sync_error': syncError,
      if (id != null) 'id': id,
      if (cowId != null) 'cow_id': cowId,
      if (recordDate != null) 'record_date': recordDate,
      if (temperatureC != null) 'temperature_c': temperatureC,
      if (milkL != null) 'milk_l': milkL,
      if (feedKg != null) 'feed_kg': feedKg,
      if (udderSwelling != null) 'udder_swelling': udderSwelling,
      if (abnormalMilk != null) 'abnormal_milk': abnormalMilk,
      if (udderPain != null) 'udder_pain': udderPain,
      if (lethargy != null) 'lethargy': lethargy,
      if (udderRedness != null) 'udder_redness': udderRedness,
      if (udderHeat != null) 'udder_heat': udderHeat,
      if (ateNormally != null) 'ate_normally': ateNormally,
      if (milkDrop != null) 'milk_drop': milkDrop,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyRecordsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? syncPending,
    Value<bool>? isDemo,
    Value<String?>? syncError,
    Value<String>? id,
    Value<String>? cowId,
    Value<String>? recordDate,
    Value<double?>? temperatureC,
    Value<double?>? milkL,
    Value<double?>? feedKg,
    Value<bool>? udderSwelling,
    Value<bool>? abnormalMilk,
    Value<bool>? udderPain,
    Value<bool>? lethargy,
    Value<bool>? udderRedness,
    Value<bool>? udderHeat,
    Value<bool?>? ateNormally,
    Value<bool?>? milkDrop,
    Value<String?>? notes,
    Value<int>? rowid,
  }) {
    return DailyRecordsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      syncPending: syncPending ?? this.syncPending,
      isDemo: isDemo ?? this.isDemo,
      syncError: syncError ?? this.syncError,
      id: id ?? this.id,
      cowId: cowId ?? this.cowId,
      recordDate: recordDate ?? this.recordDate,
      temperatureC: temperatureC ?? this.temperatureC,
      milkL: milkL ?? this.milkL,
      feedKg: feedKg ?? this.feedKg,
      udderSwelling: udderSwelling ?? this.udderSwelling,
      abnormalMilk: abnormalMilk ?? this.abnormalMilk,
      udderPain: udderPain ?? this.udderPain,
      lethargy: lethargy ?? this.lethargy,
      udderRedness: udderRedness ?? this.udderRedness,
      udderHeat: udderHeat ?? this.udderHeat,
      ateNormally: ateNormally ?? this.ateNormally,
      milkDrop: milkDrop ?? this.milkDrop,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (syncPending.present) {
      map['sync_pending'] = Variable<bool>(syncPending.value);
    }
    if (isDemo.present) {
      map['is_demo'] = Variable<bool>(isDemo.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cowId.present) {
      map['cow_id'] = Variable<String>(cowId.value);
    }
    if (recordDate.present) {
      map['record_date'] = Variable<String>(recordDate.value);
    }
    if (temperatureC.present) {
      map['temperature_c'] = Variable<double>(temperatureC.value);
    }
    if (milkL.present) {
      map['milk_l'] = Variable<double>(milkL.value);
    }
    if (feedKg.present) {
      map['feed_kg'] = Variable<double>(feedKg.value);
    }
    if (udderSwelling.present) {
      map['udder_swelling'] = Variable<bool>(udderSwelling.value);
    }
    if (abnormalMilk.present) {
      map['abnormal_milk'] = Variable<bool>(abnormalMilk.value);
    }
    if (udderPain.present) {
      map['udder_pain'] = Variable<bool>(udderPain.value);
    }
    if (lethargy.present) {
      map['lethargy'] = Variable<bool>(lethargy.value);
    }
    if (udderRedness.present) {
      map['udder_redness'] = Variable<bool>(udderRedness.value);
    }
    if (udderHeat.present) {
      map['udder_heat'] = Variable<bool>(udderHeat.value);
    }
    if (ateNormally.present) {
      map['ate_normally'] = Variable<bool>(ateNormally.value);
    }
    if (milkDrop.present) {
      map['milk_drop'] = Variable<bool>(milkDrop.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyRecordsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('syncPending: $syncPending, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncError: $syncError, ')
          ..write('id: $id, ')
          ..write('cowId: $cowId, ')
          ..write('recordDate: $recordDate, ')
          ..write('temperatureC: $temperatureC, ')
          ..write('milkL: $milkL, ')
          ..write('feedKg: $feedKg, ')
          ..write('udderSwelling: $udderSwelling, ')
          ..write('abnormalMilk: $abnormalMilk, ')
          ..write('udderPain: $udderPain, ')
          ..write('lethargy: $lethargy, ')
          ..write('udderRedness: $udderRedness, ')
          ..write('udderHeat: $udderHeat, ')
          ..write('ateNormally: $ateNormally, ')
          ..write('milkDrop: $milkDrop, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InferencesTable extends Inferences
    with TableInfo<$InferencesTable, InferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
  static const VerificationMeta _syncPendingMeta = const VerificationMeta(
    'syncPending',
  );
  @override
  late final GeneratedColumn<bool> syncPending = GeneratedColumn<bool>(
    'sync_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDemoMeta = const VerificationMeta('isDemo');
  @override
  late final GeneratedColumn<bool> isDemo = GeneratedColumn<bool>(
    'is_demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cowIdMeta = const VerificationMeta('cowId');
  @override
  late final GeneratedColumn<String> cowId = GeneratedColumn<String>(
    'cow_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cows (id)',
    ),
  );
  static const VerificationMeta _windowEndDateMeta = const VerificationMeta(
    'windowEndDate',
  );
  @override
  late final GeneratedColumn<String> windowEndDate = GeneratedColumn<String>(
    'window_end_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _probabilityMeta = const VerificationMeta(
    'probability',
  );
  @override
  late final GeneratedColumn<double> probability = GeneratedColumn<double>(
    'probability',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _symptomScoreMeta = const VerificationMeta(
    'symptomScore',
  );
  @override
  late final GeneratedColumn<int> symptomScore = GeneratedColumn<int>(
    'symptom_score',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _causeMeta = const VerificationMeta('cause');
  @override
  late final GeneratedColumn<String> cause = GeneratedColumn<String>(
    'cause',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _riskLevelMeta = const VerificationMeta(
    'riskLevel',
  );
  @override
  late final GeneratedColumn<String> riskLevel = GeneratedColumn<String>(
    'risk_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelVersionMeta = const VerificationMeta(
    'modelVersion',
  );
  @override
  late final GeneratedColumn<String> modelVersion = GeneratedColumn<String>(
    'model_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    syncPending,
    isDemo,
    syncError,
    id,
    cowId,
    windowEndDate,
    probability,
    symptomScore,
    cause,
    riskLevel,
    modelVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'inferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<InferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('sync_pending')) {
      context.handle(
        _syncPendingMeta,
        syncPending.isAcceptableOrUnknown(
          data['sync_pending']!,
          _syncPendingMeta,
        ),
      );
    }
    if (data.containsKey('is_demo')) {
      context.handle(
        _isDemoMeta,
        isDemo.isAcceptableOrUnknown(data['is_demo']!, _isDemoMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cow_id')) {
      context.handle(
        _cowIdMeta,
        cowId.isAcceptableOrUnknown(data['cow_id']!, _cowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cowIdMeta);
    }
    if (data.containsKey('window_end_date')) {
      context.handle(
        _windowEndDateMeta,
        windowEndDate.isAcceptableOrUnknown(
          data['window_end_date']!,
          _windowEndDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_windowEndDateMeta);
    }
    if (data.containsKey('probability')) {
      context.handle(
        _probabilityMeta,
        probability.isAcceptableOrUnknown(
          data['probability']!,
          _probabilityMeta,
        ),
      );
    }
    if (data.containsKey('symptom_score')) {
      context.handle(
        _symptomScoreMeta,
        symptomScore.isAcceptableOrUnknown(
          data['symptom_score']!,
          _symptomScoreMeta,
        ),
      );
    }
    if (data.containsKey('cause')) {
      context.handle(
        _causeMeta,
        cause.isAcceptableOrUnknown(data['cause']!, _causeMeta),
      );
    }
    if (data.containsKey('risk_level')) {
      context.handle(
        _riskLevelMeta,
        riskLevel.isAcceptableOrUnknown(data['risk_level']!, _riskLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_riskLevelMeta);
    }
    if (data.containsKey('model_version')) {
      context.handle(
        _modelVersionMeta,
        modelVersion.isAcceptableOrUnknown(
          data['model_version']!,
          _modelVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modelVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InferenceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InferenceRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      syncPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_pending'],
      )!,
      isDemo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_demo'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cow_id'],
      )!,
      windowEndDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}window_end_date'],
      )!,
      probability: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}probability'],
      ),
      symptomScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}symptom_score'],
      ),
      cause: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cause'],
      ),
      riskLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}risk_level'],
      )!,
      modelVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model_version'],
      )!,
    );
  }

  @override
  $InferencesTable createAlias(String alias) {
    return $InferencesTable(attachedDatabase, alias);
  }
}

class InferenceRow extends DataClass implements Insertable<InferenceRow> {
  final DateTime updatedAt;
  final bool deleted;
  final bool syncPending;

  /// Datos de demostración (solo en modo debug); nunca se sincronizan.
  final bool isDemo;

  /// Motivo por el que el servidor rechazó el elemento (no se reintenta hasta que cambie).
  final String? syncError;
  final String id;
  final String cowId;
  final String windowEndDate;

  /// Probabilidad del modelo; null si no hubo días suficientes con datos numéricos.
  final double? probability;

  /// Puntaje por síntomas del día (reglas provisionales).
  final int? symptomScore;

  /// Qué fijó el color final: MODEL, SYMPTOMS o BOTH.
  final String? cause;
  final String riskLevel;
  final String modelVersion;
  const InferenceRow({
    required this.updatedAt,
    required this.deleted,
    required this.syncPending,
    required this.isDemo,
    this.syncError,
    required this.id,
    required this.cowId,
    required this.windowEndDate,
    this.probability,
    this.symptomScore,
    this.cause,
    required this.riskLevel,
    required this.modelVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['sync_pending'] = Variable<bool>(syncPending);
    map['is_demo'] = Variable<bool>(isDemo);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['id'] = Variable<String>(id);
    map['cow_id'] = Variable<String>(cowId);
    map['window_end_date'] = Variable<String>(windowEndDate);
    if (!nullToAbsent || probability != null) {
      map['probability'] = Variable<double>(probability);
    }
    if (!nullToAbsent || symptomScore != null) {
      map['symptom_score'] = Variable<int>(symptomScore);
    }
    if (!nullToAbsent || cause != null) {
      map['cause'] = Variable<String>(cause);
    }
    map['risk_level'] = Variable<String>(riskLevel);
    map['model_version'] = Variable<String>(modelVersion);
    return map;
  }

  InferencesCompanion toCompanion(bool nullToAbsent) {
    return InferencesCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      syncPending: Value(syncPending),
      isDemo: Value(isDemo),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      id: Value(id),
      cowId: Value(cowId),
      windowEndDate: Value(windowEndDate),
      probability: probability == null && nullToAbsent
          ? const Value.absent()
          : Value(probability),
      symptomScore: symptomScore == null && nullToAbsent
          ? const Value.absent()
          : Value(symptomScore),
      cause: cause == null && nullToAbsent
          ? const Value.absent()
          : Value(cause),
      riskLevel: Value(riskLevel),
      modelVersion: Value(modelVersion),
    );
  }

  factory InferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InferenceRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      syncPending: serializer.fromJson<bool>(json['syncPending']),
      isDemo: serializer.fromJson<bool>(json['isDemo']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      id: serializer.fromJson<String>(json['id']),
      cowId: serializer.fromJson<String>(json['cowId']),
      windowEndDate: serializer.fromJson<String>(json['windowEndDate']),
      probability: serializer.fromJson<double?>(json['probability']),
      symptomScore: serializer.fromJson<int?>(json['symptomScore']),
      cause: serializer.fromJson<String?>(json['cause']),
      riskLevel: serializer.fromJson<String>(json['riskLevel']),
      modelVersion: serializer.fromJson<String>(json['modelVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'syncPending': serializer.toJson<bool>(syncPending),
      'isDemo': serializer.toJson<bool>(isDemo),
      'syncError': serializer.toJson<String?>(syncError),
      'id': serializer.toJson<String>(id),
      'cowId': serializer.toJson<String>(cowId),
      'windowEndDate': serializer.toJson<String>(windowEndDate),
      'probability': serializer.toJson<double?>(probability),
      'symptomScore': serializer.toJson<int?>(symptomScore),
      'cause': serializer.toJson<String?>(cause),
      'riskLevel': serializer.toJson<String>(riskLevel),
      'modelVersion': serializer.toJson<String>(modelVersion),
    };
  }

  InferenceRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? syncPending,
    bool? isDemo,
    Value<String?> syncError = const Value.absent(),
    String? id,
    String? cowId,
    String? windowEndDate,
    Value<double?> probability = const Value.absent(),
    Value<int?> symptomScore = const Value.absent(),
    Value<String?> cause = const Value.absent(),
    String? riskLevel,
    String? modelVersion,
  }) => InferenceRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    syncPending: syncPending ?? this.syncPending,
    isDemo: isDemo ?? this.isDemo,
    syncError: syncError.present ? syncError.value : this.syncError,
    id: id ?? this.id,
    cowId: cowId ?? this.cowId,
    windowEndDate: windowEndDate ?? this.windowEndDate,
    probability: probability.present ? probability.value : this.probability,
    symptomScore: symptomScore.present ? symptomScore.value : this.symptomScore,
    cause: cause.present ? cause.value : this.cause,
    riskLevel: riskLevel ?? this.riskLevel,
    modelVersion: modelVersion ?? this.modelVersion,
  );
  InferenceRow copyWithCompanion(InferencesCompanion data) {
    return InferenceRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      syncPending: data.syncPending.present
          ? data.syncPending.value
          : this.syncPending,
      isDemo: data.isDemo.present ? data.isDemo.value : this.isDemo,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      id: data.id.present ? data.id.value : this.id,
      cowId: data.cowId.present ? data.cowId.value : this.cowId,
      windowEndDate: data.windowEndDate.present
          ? data.windowEndDate.value
          : this.windowEndDate,
      probability: data.probability.present
          ? data.probability.value
          : this.probability,
      symptomScore: data.symptomScore.present
          ? data.symptomScore.value
          : this.symptomScore,
      cause: data.cause.present ? data.cause.value : this.cause,
      riskLevel: data.riskLevel.present ? data.riskLevel.value : this.riskLevel,
      modelVersion: data.modelVersion.present
          ? data.modelVersion.value
          : this.modelVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InferenceRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('syncPending: $syncPending, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncError: $syncError, ')
          ..write('id: $id, ')
          ..write('cowId: $cowId, ')
          ..write('windowEndDate: $windowEndDate, ')
          ..write('probability: $probability, ')
          ..write('symptomScore: $symptomScore, ')
          ..write('cause: $cause, ')
          ..write('riskLevel: $riskLevel, ')
          ..write('modelVersion: $modelVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deleted,
    syncPending,
    isDemo,
    syncError,
    id,
    cowId,
    windowEndDate,
    probability,
    symptomScore,
    cause,
    riskLevel,
    modelVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InferenceRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.syncPending == this.syncPending &&
          other.isDemo == this.isDemo &&
          other.syncError == this.syncError &&
          other.id == this.id &&
          other.cowId == this.cowId &&
          other.windowEndDate == this.windowEndDate &&
          other.probability == this.probability &&
          other.symptomScore == this.symptomScore &&
          other.cause == this.cause &&
          other.riskLevel == this.riskLevel &&
          other.modelVersion == this.modelVersion);
}

class InferencesCompanion extends UpdateCompanion<InferenceRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> syncPending;
  final Value<bool> isDemo;
  final Value<String?> syncError;
  final Value<String> id;
  final Value<String> cowId;
  final Value<String> windowEndDate;
  final Value<double?> probability;
  final Value<int?> symptomScore;
  final Value<String?> cause;
  final Value<String> riskLevel;
  final Value<String> modelVersion;
  final Value<int> rowid;
  const InferencesCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncError = const Value.absent(),
    this.id = const Value.absent(),
    this.cowId = const Value.absent(),
    this.windowEndDate = const Value.absent(),
    this.probability = const Value.absent(),
    this.symptomScore = const Value.absent(),
    this.cause = const Value.absent(),
    this.riskLevel = const Value.absent(),
    this.modelVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InferencesCompanion.insert({
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncError = const Value.absent(),
    required String id,
    required String cowId,
    required String windowEndDate,
    this.probability = const Value.absent(),
    this.symptomScore = const Value.absent(),
    this.cause = const Value.absent(),
    required String riskLevel,
    required String modelVersion,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       cowId = Value(cowId),
       windowEndDate = Value(windowEndDate),
       riskLevel = Value(riskLevel),
       modelVersion = Value(modelVersion);
  static Insertable<InferenceRow> custom({
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? syncPending,
    Expression<bool>? isDemo,
    Expression<String>? syncError,
    Expression<String>? id,
    Expression<String>? cowId,
    Expression<String>? windowEndDate,
    Expression<double>? probability,
    Expression<int>? symptomScore,
    Expression<String>? cause,
    Expression<String>? riskLevel,
    Expression<String>? modelVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (syncPending != null) 'sync_pending': syncPending,
      if (isDemo != null) 'is_demo': isDemo,
      if (syncError != null) 'sync_error': syncError,
      if (id != null) 'id': id,
      if (cowId != null) 'cow_id': cowId,
      if (windowEndDate != null) 'window_end_date': windowEndDate,
      if (probability != null) 'probability': probability,
      if (symptomScore != null) 'symptom_score': symptomScore,
      if (cause != null) 'cause': cause,
      if (riskLevel != null) 'risk_level': riskLevel,
      if (modelVersion != null) 'model_version': modelVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InferencesCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? syncPending,
    Value<bool>? isDemo,
    Value<String?>? syncError,
    Value<String>? id,
    Value<String>? cowId,
    Value<String>? windowEndDate,
    Value<double?>? probability,
    Value<int?>? symptomScore,
    Value<String?>? cause,
    Value<String>? riskLevel,
    Value<String>? modelVersion,
    Value<int>? rowid,
  }) {
    return InferencesCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      syncPending: syncPending ?? this.syncPending,
      isDemo: isDemo ?? this.isDemo,
      syncError: syncError ?? this.syncError,
      id: id ?? this.id,
      cowId: cowId ?? this.cowId,
      windowEndDate: windowEndDate ?? this.windowEndDate,
      probability: probability ?? this.probability,
      symptomScore: symptomScore ?? this.symptomScore,
      cause: cause ?? this.cause,
      riskLevel: riskLevel ?? this.riskLevel,
      modelVersion: modelVersion ?? this.modelVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (syncPending.present) {
      map['sync_pending'] = Variable<bool>(syncPending.value);
    }
    if (isDemo.present) {
      map['is_demo'] = Variable<bool>(isDemo.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cowId.present) {
      map['cow_id'] = Variable<String>(cowId.value);
    }
    if (windowEndDate.present) {
      map['window_end_date'] = Variable<String>(windowEndDate.value);
    }
    if (probability.present) {
      map['probability'] = Variable<double>(probability.value);
    }
    if (symptomScore.present) {
      map['symptom_score'] = Variable<int>(symptomScore.value);
    }
    if (cause.present) {
      map['cause'] = Variable<String>(cause.value);
    }
    if (riskLevel.present) {
      map['risk_level'] = Variable<String>(riskLevel.value);
    }
    if (modelVersion.present) {
      map['model_version'] = Variable<String>(modelVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InferencesCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('syncPending: $syncPending, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncError: $syncError, ')
          ..write('id: $id, ')
          ..write('cowId: $cowId, ')
          ..write('windowEndDate: $windowEndDate, ')
          ..write('probability: $probability, ')
          ..write('symptomScore: $symptomScore, ')
          ..write('cause: $cause, ')
          ..write('riskLevel: $riskLevel, ')
          ..write('modelVersion: $modelVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AlertsTable extends Alerts with TableInfo<$AlertsTable, AlertRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AlertsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
  static const VerificationMeta _syncPendingMeta = const VerificationMeta(
    'syncPending',
  );
  @override
  late final GeneratedColumn<bool> syncPending = GeneratedColumn<bool>(
    'sync_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDemoMeta = const VerificationMeta('isDemo');
  @override
  late final GeneratedColumn<bool> isDemo = GeneratedColumn<bool>(
    'is_demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cowIdMeta = const VerificationMeta('cowId');
  @override
  late final GeneratedColumn<String> cowId = GeneratedColumn<String>(
    'cow_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cows (id)',
    ),
  );
  static const VerificationMeta _inferenceIdMeta = const VerificationMeta(
    'inferenceId',
  );
  @override
  late final GeneratedColumn<String> inferenceId = GeneratedColumn<String>(
    'inference_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES inferences (id)',
    ),
  );
  static const VerificationMeta _riskLevelMeta = const VerificationMeta(
    'riskLevel',
  );
  @override
  late final GeneratedColumn<String> riskLevel = GeneratedColumn<String>(
    'risk_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attendedMeta = const VerificationMeta(
    'attended',
  );
  @override
  late final GeneratedColumn<bool> attended = GeneratedColumn<bool>(
    'attended',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("attended" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _attendedAtMeta = const VerificationMeta(
    'attendedAt',
  );
  @override
  late final GeneratedColumn<DateTime> attendedAt = GeneratedColumn<DateTime>(
    'attended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    syncPending,
    isDemo,
    syncError,
    id,
    cowId,
    inferenceId,
    riskLevel,
    attended,
    attendedAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'alerts';
  @override
  VerificationContext validateIntegrity(
    Insertable<AlertRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('sync_pending')) {
      context.handle(
        _syncPendingMeta,
        syncPending.isAcceptableOrUnknown(
          data['sync_pending']!,
          _syncPendingMeta,
        ),
      );
    }
    if (data.containsKey('is_demo')) {
      context.handle(
        _isDemoMeta,
        isDemo.isAcceptableOrUnknown(data['is_demo']!, _isDemoMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cow_id')) {
      context.handle(
        _cowIdMeta,
        cowId.isAcceptableOrUnknown(data['cow_id']!, _cowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cowIdMeta);
    }
    if (data.containsKey('inference_id')) {
      context.handle(
        _inferenceIdMeta,
        inferenceId.isAcceptableOrUnknown(
          data['inference_id']!,
          _inferenceIdMeta,
        ),
      );
    }
    if (data.containsKey('risk_level')) {
      context.handle(
        _riskLevelMeta,
        riskLevel.isAcceptableOrUnknown(data['risk_level']!, _riskLevelMeta),
      );
    } else if (isInserting) {
      context.missing(_riskLevelMeta);
    }
    if (data.containsKey('attended')) {
      context.handle(
        _attendedMeta,
        attended.isAcceptableOrUnknown(data['attended']!, _attendedMeta),
      );
    }
    if (data.containsKey('attended_at')) {
      context.handle(
        _attendedAtMeta,
        attendedAt.isAcceptableOrUnknown(data['attended_at']!, _attendedAtMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AlertRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AlertRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      syncPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_pending'],
      )!,
      isDemo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_demo'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cow_id'],
      )!,
      inferenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inference_id'],
      ),
      riskLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}risk_level'],
      )!,
      attended: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}attended'],
      )!,
      attendedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}attended_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AlertsTable createAlias(String alias) {
    return $AlertsTable(attachedDatabase, alias);
  }
}

class AlertRow extends DataClass implements Insertable<AlertRow> {
  final DateTime updatedAt;
  final bool deleted;
  final bool syncPending;

  /// Datos de demostración (solo en modo debug); nunca se sincronizan.
  final bool isDemo;

  /// Motivo por el que el servidor rechazó el elemento (no se reintenta hasta que cambie).
  final String? syncError;
  final String id;
  final String cowId;
  final String? inferenceId;
  final String riskLevel;
  final bool attended;
  final DateTime? attendedAt;
  final DateTime createdAt;
  const AlertRow({
    required this.updatedAt,
    required this.deleted,
    required this.syncPending,
    required this.isDemo,
    this.syncError,
    required this.id,
    required this.cowId,
    this.inferenceId,
    required this.riskLevel,
    required this.attended,
    this.attendedAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['sync_pending'] = Variable<bool>(syncPending);
    map['is_demo'] = Variable<bool>(isDemo);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['id'] = Variable<String>(id);
    map['cow_id'] = Variable<String>(cowId);
    if (!nullToAbsent || inferenceId != null) {
      map['inference_id'] = Variable<String>(inferenceId);
    }
    map['risk_level'] = Variable<String>(riskLevel);
    map['attended'] = Variable<bool>(attended);
    if (!nullToAbsent || attendedAt != null) {
      map['attended_at'] = Variable<DateTime>(attendedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AlertsCompanion toCompanion(bool nullToAbsent) {
    return AlertsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      syncPending: Value(syncPending),
      isDemo: Value(isDemo),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      id: Value(id),
      cowId: Value(cowId),
      inferenceId: inferenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(inferenceId),
      riskLevel: Value(riskLevel),
      attended: Value(attended),
      attendedAt: attendedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(attendedAt),
      createdAt: Value(createdAt),
    );
  }

  factory AlertRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AlertRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      syncPending: serializer.fromJson<bool>(json['syncPending']),
      isDemo: serializer.fromJson<bool>(json['isDemo']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      id: serializer.fromJson<String>(json['id']),
      cowId: serializer.fromJson<String>(json['cowId']),
      inferenceId: serializer.fromJson<String?>(json['inferenceId']),
      riskLevel: serializer.fromJson<String>(json['riskLevel']),
      attended: serializer.fromJson<bool>(json['attended']),
      attendedAt: serializer.fromJson<DateTime?>(json['attendedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'syncPending': serializer.toJson<bool>(syncPending),
      'isDemo': serializer.toJson<bool>(isDemo),
      'syncError': serializer.toJson<String?>(syncError),
      'id': serializer.toJson<String>(id),
      'cowId': serializer.toJson<String>(cowId),
      'inferenceId': serializer.toJson<String?>(inferenceId),
      'riskLevel': serializer.toJson<String>(riskLevel),
      'attended': serializer.toJson<bool>(attended),
      'attendedAt': serializer.toJson<DateTime?>(attendedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AlertRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? syncPending,
    bool? isDemo,
    Value<String?> syncError = const Value.absent(),
    String? id,
    String? cowId,
    Value<String?> inferenceId = const Value.absent(),
    String? riskLevel,
    bool? attended,
    Value<DateTime?> attendedAt = const Value.absent(),
    DateTime? createdAt,
  }) => AlertRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    syncPending: syncPending ?? this.syncPending,
    isDemo: isDemo ?? this.isDemo,
    syncError: syncError.present ? syncError.value : this.syncError,
    id: id ?? this.id,
    cowId: cowId ?? this.cowId,
    inferenceId: inferenceId.present ? inferenceId.value : this.inferenceId,
    riskLevel: riskLevel ?? this.riskLevel,
    attended: attended ?? this.attended,
    attendedAt: attendedAt.present ? attendedAt.value : this.attendedAt,
    createdAt: createdAt ?? this.createdAt,
  );
  AlertRow copyWithCompanion(AlertsCompanion data) {
    return AlertRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      syncPending: data.syncPending.present
          ? data.syncPending.value
          : this.syncPending,
      isDemo: data.isDemo.present ? data.isDemo.value : this.isDemo,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      id: data.id.present ? data.id.value : this.id,
      cowId: data.cowId.present ? data.cowId.value : this.cowId,
      inferenceId: data.inferenceId.present
          ? data.inferenceId.value
          : this.inferenceId,
      riskLevel: data.riskLevel.present ? data.riskLevel.value : this.riskLevel,
      attended: data.attended.present ? data.attended.value : this.attended,
      attendedAt: data.attendedAt.present
          ? data.attendedAt.value
          : this.attendedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AlertRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('syncPending: $syncPending, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncError: $syncError, ')
          ..write('id: $id, ')
          ..write('cowId: $cowId, ')
          ..write('inferenceId: $inferenceId, ')
          ..write('riskLevel: $riskLevel, ')
          ..write('attended: $attended, ')
          ..write('attendedAt: $attendedAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deleted,
    syncPending,
    isDemo,
    syncError,
    id,
    cowId,
    inferenceId,
    riskLevel,
    attended,
    attendedAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AlertRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.syncPending == this.syncPending &&
          other.isDemo == this.isDemo &&
          other.syncError == this.syncError &&
          other.id == this.id &&
          other.cowId == this.cowId &&
          other.inferenceId == this.inferenceId &&
          other.riskLevel == this.riskLevel &&
          other.attended == this.attended &&
          other.attendedAt == this.attendedAt &&
          other.createdAt == this.createdAt);
}

class AlertsCompanion extends UpdateCompanion<AlertRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> syncPending;
  final Value<bool> isDemo;
  final Value<String?> syncError;
  final Value<String> id;
  final Value<String> cowId;
  final Value<String?> inferenceId;
  final Value<String> riskLevel;
  final Value<bool> attended;
  final Value<DateTime?> attendedAt;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AlertsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncError = const Value.absent(),
    this.id = const Value.absent(),
    this.cowId = const Value.absent(),
    this.inferenceId = const Value.absent(),
    this.riskLevel = const Value.absent(),
    this.attended = const Value.absent(),
    this.attendedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AlertsCompanion.insert({
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncError = const Value.absent(),
    required String id,
    required String cowId,
    this.inferenceId = const Value.absent(),
    required String riskLevel,
    this.attended = const Value.absent(),
    this.attendedAt = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       cowId = Value(cowId),
       riskLevel = Value(riskLevel),
       createdAt = Value(createdAt);
  static Insertable<AlertRow> custom({
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? syncPending,
    Expression<bool>? isDemo,
    Expression<String>? syncError,
    Expression<String>? id,
    Expression<String>? cowId,
    Expression<String>? inferenceId,
    Expression<String>? riskLevel,
    Expression<bool>? attended,
    Expression<DateTime>? attendedAt,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (syncPending != null) 'sync_pending': syncPending,
      if (isDemo != null) 'is_demo': isDemo,
      if (syncError != null) 'sync_error': syncError,
      if (id != null) 'id': id,
      if (cowId != null) 'cow_id': cowId,
      if (inferenceId != null) 'inference_id': inferenceId,
      if (riskLevel != null) 'risk_level': riskLevel,
      if (attended != null) 'attended': attended,
      if (attendedAt != null) 'attended_at': attendedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AlertsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? syncPending,
    Value<bool>? isDemo,
    Value<String?>? syncError,
    Value<String>? id,
    Value<String>? cowId,
    Value<String?>? inferenceId,
    Value<String>? riskLevel,
    Value<bool>? attended,
    Value<DateTime?>? attendedAt,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AlertsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      syncPending: syncPending ?? this.syncPending,
      isDemo: isDemo ?? this.isDemo,
      syncError: syncError ?? this.syncError,
      id: id ?? this.id,
      cowId: cowId ?? this.cowId,
      inferenceId: inferenceId ?? this.inferenceId,
      riskLevel: riskLevel ?? this.riskLevel,
      attended: attended ?? this.attended,
      attendedAt: attendedAt ?? this.attendedAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (syncPending.present) {
      map['sync_pending'] = Variable<bool>(syncPending.value);
    }
    if (isDemo.present) {
      map['is_demo'] = Variable<bool>(isDemo.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cowId.present) {
      map['cow_id'] = Variable<String>(cowId.value);
    }
    if (inferenceId.present) {
      map['inference_id'] = Variable<String>(inferenceId.value);
    }
    if (riskLevel.present) {
      map['risk_level'] = Variable<String>(riskLevel.value);
    }
    if (attended.present) {
      map['attended'] = Variable<bool>(attended.value);
    }
    if (attendedAt.present) {
      map['attended_at'] = Variable<DateTime>(attendedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AlertsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('syncPending: $syncPending, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncError: $syncError, ')
          ..write('id: $id, ')
          ..write('cowId: $cowId, ')
          ..write('inferenceId: $inferenceId, ')
          ..write('riskLevel: $riskLevel, ')
          ..write('attended: $attended, ')
          ..write('attendedAt: $attendedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CowPhotosTable extends CowPhotos
    with TableInfo<$CowPhotosTable, CowPhotoRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CowPhotosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
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
  static const VerificationMeta _syncPendingMeta = const VerificationMeta(
    'syncPending',
  );
  @override
  late final GeneratedColumn<bool> syncPending = GeneratedColumn<bool>(
    'sync_pending',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sync_pending" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDemoMeta = const VerificationMeta('isDemo');
  @override
  late final GeneratedColumn<bool> isDemo = GeneratedColumn<bool>(
    'is_demo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_demo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _syncErrorMeta = const VerificationMeta(
    'syncError',
  );
  @override
  late final GeneratedColumn<String> syncError = GeneratedColumn<String>(
    'sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cowIdMeta = const VerificationMeta('cowId');
  @override
  late final GeneratedColumn<String> cowId = GeneratedColumn<String>(
    'cow_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cows (id)',
    ),
  );
  static const VerificationMeta _takenOnMeta = const VerificationMeta(
    'takenOn',
  );
  @override
  late final GeneratedColumn<String> takenOn = GeneratedColumn<String>(
    'taken_on',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageUploadedMeta = const VerificationMeta(
    'imageUploaded',
  );
  @override
  late final GeneratedColumn<bool> imageUploaded = GeneratedColumn<bool>(
    'image_uploaded',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("image_uploaded" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _vetConfirmedMeta = const VerificationMeta(
    'vetConfirmed',
  );
  @override
  late final GeneratedColumn<String> vetConfirmed = GeneratedColumn<String>(
    'vet_confirmed',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diagnosisMeta = const VerificationMeta(
    'diagnosis',
  );
  @override
  late final GeneratedColumn<String> diagnosis = GeneratedColumn<String>(
    'diagnosis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diagnosisNotesMeta = const VerificationMeta(
    'diagnosisNotes',
  );
  @override
  late final GeneratedColumn<String> diagnosisNotes = GeneratedColumn<String>(
    'diagnosis_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _researchConsentMeta = const VerificationMeta(
    'researchConsent',
  );
  @override
  late final GeneratedColumn<bool> researchConsent = GeneratedColumn<bool>(
    'research_consent',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("research_consent" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    syncPending,
    isDemo,
    syncError,
    id,
    cowId,
    takenOn,
    fileName,
    sizeBytes,
    imageUploaded,
    vetConfirmed,
    diagnosis,
    diagnosisNotes,
    researchConsent,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cow_photos';
  @override
  VerificationContext validateIntegrity(
    Insertable<CowPhotoRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('sync_pending')) {
      context.handle(
        _syncPendingMeta,
        syncPending.isAcceptableOrUnknown(
          data['sync_pending']!,
          _syncPendingMeta,
        ),
      );
    }
    if (data.containsKey('is_demo')) {
      context.handle(
        _isDemoMeta,
        isDemo.isAcceptableOrUnknown(data['is_demo']!, _isDemoMeta),
      );
    }
    if (data.containsKey('sync_error')) {
      context.handle(
        _syncErrorMeta,
        syncError.isAcceptableOrUnknown(data['sync_error']!, _syncErrorMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cow_id')) {
      context.handle(
        _cowIdMeta,
        cowId.isAcceptableOrUnknown(data['cow_id']!, _cowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cowIdMeta);
    }
    if (data.containsKey('taken_on')) {
      context.handle(
        _takenOnMeta,
        takenOn.isAcceptableOrUnknown(data['taken_on']!, _takenOnMeta),
      );
    } else if (isInserting) {
      context.missing(_takenOnMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('image_uploaded')) {
      context.handle(
        _imageUploadedMeta,
        imageUploaded.isAcceptableOrUnknown(
          data['image_uploaded']!,
          _imageUploadedMeta,
        ),
      );
    }
    if (data.containsKey('vet_confirmed')) {
      context.handle(
        _vetConfirmedMeta,
        vetConfirmed.isAcceptableOrUnknown(
          data['vet_confirmed']!,
          _vetConfirmedMeta,
        ),
      );
    }
    if (data.containsKey('diagnosis')) {
      context.handle(
        _diagnosisMeta,
        diagnosis.isAcceptableOrUnknown(data['diagnosis']!, _diagnosisMeta),
      );
    }
    if (data.containsKey('diagnosis_notes')) {
      context.handle(
        _diagnosisNotesMeta,
        diagnosisNotes.isAcceptableOrUnknown(
          data['diagnosis_notes']!,
          _diagnosisNotesMeta,
        ),
      );
    }
    if (data.containsKey('research_consent')) {
      context.handle(
        _researchConsentMeta,
        researchConsent.isAcceptableOrUnknown(
          data['research_consent']!,
          _researchConsentMeta,
        ),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CowPhotoRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CowPhotoRow(
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      syncPending: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sync_pending'],
      )!,
      isDemo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_demo'],
      )!,
      syncError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_error'],
      ),
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cow_id'],
      )!,
      takenOn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}taken_on'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      imageUploaded: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}image_uploaded'],
      )!,
      vetConfirmed: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vet_confirmed'],
      ),
      diagnosis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diagnosis'],
      ),
      diagnosisNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}diagnosis_notes'],
      ),
      researchConsent: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}research_consent'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CowPhotosTable createAlias(String alias) {
    return $CowPhotosTable(attachedDatabase, alias);
  }
}

class CowPhotoRow extends DataClass implements Insertable<CowPhotoRow> {
  final DateTime updatedAt;
  final bool deleted;
  final bool syncPending;

  /// Datos de demostración (solo en modo debug); nunca se sincronizan.
  final bool isDemo;

  /// Motivo por el que el servidor rechazó el elemento (no se reintenta hasta que cambie).
  final String? syncError;
  final String id;
  final String cowId;

  /// Día de la foto como texto AAAA-MM-DD.
  final String takenOn;
  final String fileName;
  final int sizeBytes;

  /// El archivo ya se subió al servidor (los datos viajan aparte, con la sincronización).
  final bool imageUploaded;

  /// ¿Lo confirmó un veterinario? YES, NO o PENDING (null: sin responder).
  final String? vetConfirmed;

  /// MASTITIS, HEALTHY u OTHER.
  final String? diagnosis;
  final String? diagnosisNotes;

  /// Permiso expreso para usar la foto en investigación; apagado por defecto.
  final bool researchConsent;
  final DateTime createdAt;
  const CowPhotoRow({
    required this.updatedAt,
    required this.deleted,
    required this.syncPending,
    required this.isDemo,
    this.syncError,
    required this.id,
    required this.cowId,
    required this.takenOn,
    required this.fileName,
    required this.sizeBytes,
    required this.imageUploaded,
    this.vetConfirmed,
    this.diagnosis,
    this.diagnosisNotes,
    required this.researchConsent,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['sync_pending'] = Variable<bool>(syncPending);
    map['is_demo'] = Variable<bool>(isDemo);
    if (!nullToAbsent || syncError != null) {
      map['sync_error'] = Variable<String>(syncError);
    }
    map['id'] = Variable<String>(id);
    map['cow_id'] = Variable<String>(cowId);
    map['taken_on'] = Variable<String>(takenOn);
    map['file_name'] = Variable<String>(fileName);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['image_uploaded'] = Variable<bool>(imageUploaded);
    if (!nullToAbsent || vetConfirmed != null) {
      map['vet_confirmed'] = Variable<String>(vetConfirmed);
    }
    if (!nullToAbsent || diagnosis != null) {
      map['diagnosis'] = Variable<String>(diagnosis);
    }
    if (!nullToAbsent || diagnosisNotes != null) {
      map['diagnosis_notes'] = Variable<String>(diagnosisNotes);
    }
    map['research_consent'] = Variable<bool>(researchConsent);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CowPhotosCompanion toCompanion(bool nullToAbsent) {
    return CowPhotosCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      syncPending: Value(syncPending),
      isDemo: Value(isDemo),
      syncError: syncError == null && nullToAbsent
          ? const Value.absent()
          : Value(syncError),
      id: Value(id),
      cowId: Value(cowId),
      takenOn: Value(takenOn),
      fileName: Value(fileName),
      sizeBytes: Value(sizeBytes),
      imageUploaded: Value(imageUploaded),
      vetConfirmed: vetConfirmed == null && nullToAbsent
          ? const Value.absent()
          : Value(vetConfirmed),
      diagnosis: diagnosis == null && nullToAbsent
          ? const Value.absent()
          : Value(diagnosis),
      diagnosisNotes: diagnosisNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(diagnosisNotes),
      researchConsent: Value(researchConsent),
      createdAt: Value(createdAt),
    );
  }

  factory CowPhotoRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CowPhotoRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      syncPending: serializer.fromJson<bool>(json['syncPending']),
      isDemo: serializer.fromJson<bool>(json['isDemo']),
      syncError: serializer.fromJson<String?>(json['syncError']),
      id: serializer.fromJson<String>(json['id']),
      cowId: serializer.fromJson<String>(json['cowId']),
      takenOn: serializer.fromJson<String>(json['takenOn']),
      fileName: serializer.fromJson<String>(json['fileName']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      imageUploaded: serializer.fromJson<bool>(json['imageUploaded']),
      vetConfirmed: serializer.fromJson<String?>(json['vetConfirmed']),
      diagnosis: serializer.fromJson<String?>(json['diagnosis']),
      diagnosisNotes: serializer.fromJson<String?>(json['diagnosisNotes']),
      researchConsent: serializer.fromJson<bool>(json['researchConsent']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'syncPending': serializer.toJson<bool>(syncPending),
      'isDemo': serializer.toJson<bool>(isDemo),
      'syncError': serializer.toJson<String?>(syncError),
      'id': serializer.toJson<String>(id),
      'cowId': serializer.toJson<String>(cowId),
      'takenOn': serializer.toJson<String>(takenOn),
      'fileName': serializer.toJson<String>(fileName),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'imageUploaded': serializer.toJson<bool>(imageUploaded),
      'vetConfirmed': serializer.toJson<String?>(vetConfirmed),
      'diagnosis': serializer.toJson<String?>(diagnosis),
      'diagnosisNotes': serializer.toJson<String?>(diagnosisNotes),
      'researchConsent': serializer.toJson<bool>(researchConsent),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  CowPhotoRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? syncPending,
    bool? isDemo,
    Value<String?> syncError = const Value.absent(),
    String? id,
    String? cowId,
    String? takenOn,
    String? fileName,
    int? sizeBytes,
    bool? imageUploaded,
    Value<String?> vetConfirmed = const Value.absent(),
    Value<String?> diagnosis = const Value.absent(),
    Value<String?> diagnosisNotes = const Value.absent(),
    bool? researchConsent,
    DateTime? createdAt,
  }) => CowPhotoRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    syncPending: syncPending ?? this.syncPending,
    isDemo: isDemo ?? this.isDemo,
    syncError: syncError.present ? syncError.value : this.syncError,
    id: id ?? this.id,
    cowId: cowId ?? this.cowId,
    takenOn: takenOn ?? this.takenOn,
    fileName: fileName ?? this.fileName,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    imageUploaded: imageUploaded ?? this.imageUploaded,
    vetConfirmed: vetConfirmed.present ? vetConfirmed.value : this.vetConfirmed,
    diagnosis: diagnosis.present ? diagnosis.value : this.diagnosis,
    diagnosisNotes: diagnosisNotes.present
        ? diagnosisNotes.value
        : this.diagnosisNotes,
    researchConsent: researchConsent ?? this.researchConsent,
    createdAt: createdAt ?? this.createdAt,
  );
  CowPhotoRow copyWithCompanion(CowPhotosCompanion data) {
    return CowPhotoRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      syncPending: data.syncPending.present
          ? data.syncPending.value
          : this.syncPending,
      isDemo: data.isDemo.present ? data.isDemo.value : this.isDemo,
      syncError: data.syncError.present ? data.syncError.value : this.syncError,
      id: data.id.present ? data.id.value : this.id,
      cowId: data.cowId.present ? data.cowId.value : this.cowId,
      takenOn: data.takenOn.present ? data.takenOn.value : this.takenOn,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      imageUploaded: data.imageUploaded.present
          ? data.imageUploaded.value
          : this.imageUploaded,
      vetConfirmed: data.vetConfirmed.present
          ? data.vetConfirmed.value
          : this.vetConfirmed,
      diagnosis: data.diagnosis.present ? data.diagnosis.value : this.diagnosis,
      diagnosisNotes: data.diagnosisNotes.present
          ? data.diagnosisNotes.value
          : this.diagnosisNotes,
      researchConsent: data.researchConsent.present
          ? data.researchConsent.value
          : this.researchConsent,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CowPhotoRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('syncPending: $syncPending, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncError: $syncError, ')
          ..write('id: $id, ')
          ..write('cowId: $cowId, ')
          ..write('takenOn: $takenOn, ')
          ..write('fileName: $fileName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('imageUploaded: $imageUploaded, ')
          ..write('vetConfirmed: $vetConfirmed, ')
          ..write('diagnosis: $diagnosis, ')
          ..write('diagnosisNotes: $diagnosisNotes, ')
          ..write('researchConsent: $researchConsent, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deleted,
    syncPending,
    isDemo,
    syncError,
    id,
    cowId,
    takenOn,
    fileName,
    sizeBytes,
    imageUploaded,
    vetConfirmed,
    diagnosis,
    diagnosisNotes,
    researchConsent,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CowPhotoRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.syncPending == this.syncPending &&
          other.isDemo == this.isDemo &&
          other.syncError == this.syncError &&
          other.id == this.id &&
          other.cowId == this.cowId &&
          other.takenOn == this.takenOn &&
          other.fileName == this.fileName &&
          other.sizeBytes == this.sizeBytes &&
          other.imageUploaded == this.imageUploaded &&
          other.vetConfirmed == this.vetConfirmed &&
          other.diagnosis == this.diagnosis &&
          other.diagnosisNotes == this.diagnosisNotes &&
          other.researchConsent == this.researchConsent &&
          other.createdAt == this.createdAt);
}

class CowPhotosCompanion extends UpdateCompanion<CowPhotoRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> syncPending;
  final Value<bool> isDemo;
  final Value<String?> syncError;
  final Value<String> id;
  final Value<String> cowId;
  final Value<String> takenOn;
  final Value<String> fileName;
  final Value<int> sizeBytes;
  final Value<bool> imageUploaded;
  final Value<String?> vetConfirmed;
  final Value<String?> diagnosis;
  final Value<String?> diagnosisNotes;
  final Value<bool> researchConsent;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const CowPhotosCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncError = const Value.absent(),
    this.id = const Value.absent(),
    this.cowId = const Value.absent(),
    this.takenOn = const Value.absent(),
    this.fileName = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.imageUploaded = const Value.absent(),
    this.vetConfirmed = const Value.absent(),
    this.diagnosis = const Value.absent(),
    this.diagnosisNotes = const Value.absent(),
    this.researchConsent = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CowPhotosCompanion.insert({
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.syncPending = const Value.absent(),
    this.isDemo = const Value.absent(),
    this.syncError = const Value.absent(),
    required String id,
    required String cowId,
    required String takenOn,
    required String fileName,
    required int sizeBytes,
    this.imageUploaded = const Value.absent(),
    this.vetConfirmed = const Value.absent(),
    this.diagnosis = const Value.absent(),
    this.diagnosisNotes = const Value.absent(),
    this.researchConsent = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       id = Value(id),
       cowId = Value(cowId),
       takenOn = Value(takenOn),
       fileName = Value(fileName),
       sizeBytes = Value(sizeBytes),
       createdAt = Value(createdAt);
  static Insertable<CowPhotoRow> custom({
    Expression<DateTime>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? syncPending,
    Expression<bool>? isDemo,
    Expression<String>? syncError,
    Expression<String>? id,
    Expression<String>? cowId,
    Expression<String>? takenOn,
    Expression<String>? fileName,
    Expression<int>? sizeBytes,
    Expression<bool>? imageUploaded,
    Expression<String>? vetConfirmed,
    Expression<String>? diagnosis,
    Expression<String>? diagnosisNotes,
    Expression<bool>? researchConsent,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (syncPending != null) 'sync_pending': syncPending,
      if (isDemo != null) 'is_demo': isDemo,
      if (syncError != null) 'sync_error': syncError,
      if (id != null) 'id': id,
      if (cowId != null) 'cow_id': cowId,
      if (takenOn != null) 'taken_on': takenOn,
      if (fileName != null) 'file_name': fileName,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (imageUploaded != null) 'image_uploaded': imageUploaded,
      if (vetConfirmed != null) 'vet_confirmed': vetConfirmed,
      if (diagnosis != null) 'diagnosis': diagnosis,
      if (diagnosisNotes != null) 'diagnosis_notes': diagnosisNotes,
      if (researchConsent != null) 'research_consent': researchConsent,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CowPhotosCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? syncPending,
    Value<bool>? isDemo,
    Value<String?>? syncError,
    Value<String>? id,
    Value<String>? cowId,
    Value<String>? takenOn,
    Value<String>? fileName,
    Value<int>? sizeBytes,
    Value<bool>? imageUploaded,
    Value<String?>? vetConfirmed,
    Value<String?>? diagnosis,
    Value<String?>? diagnosisNotes,
    Value<bool>? researchConsent,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return CowPhotosCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      syncPending: syncPending ?? this.syncPending,
      isDemo: isDemo ?? this.isDemo,
      syncError: syncError ?? this.syncError,
      id: id ?? this.id,
      cowId: cowId ?? this.cowId,
      takenOn: takenOn ?? this.takenOn,
      fileName: fileName ?? this.fileName,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      imageUploaded: imageUploaded ?? this.imageUploaded,
      vetConfirmed: vetConfirmed ?? this.vetConfirmed,
      diagnosis: diagnosis ?? this.diagnosis,
      diagnosisNotes: diagnosisNotes ?? this.diagnosisNotes,
      researchConsent: researchConsent ?? this.researchConsent,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (syncPending.present) {
      map['sync_pending'] = Variable<bool>(syncPending.value);
    }
    if (isDemo.present) {
      map['is_demo'] = Variable<bool>(isDemo.value);
    }
    if (syncError.present) {
      map['sync_error'] = Variable<String>(syncError.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (cowId.present) {
      map['cow_id'] = Variable<String>(cowId.value);
    }
    if (takenOn.present) {
      map['taken_on'] = Variable<String>(takenOn.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (imageUploaded.present) {
      map['image_uploaded'] = Variable<bool>(imageUploaded.value);
    }
    if (vetConfirmed.present) {
      map['vet_confirmed'] = Variable<String>(vetConfirmed.value);
    }
    if (diagnosis.present) {
      map['diagnosis'] = Variable<String>(diagnosis.value);
    }
    if (diagnosisNotes.present) {
      map['diagnosis_notes'] = Variable<String>(diagnosisNotes.value);
    }
    if (researchConsent.present) {
      map['research_consent'] = Variable<bool>(researchConsent.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CowPhotosCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('syncPending: $syncPending, ')
          ..write('isDemo: $isDemo, ')
          ..write('syncError: $syncError, ')
          ..write('id: $id, ')
          ..write('cowId: $cowId, ')
          ..write('takenOn: $takenOn, ')
          ..write('fileName: $fileName, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('imageUploaded: $imageUploaded, ')
          ..write('vetConfirmed: $vetConfirmed, ')
          ..write('diagnosis: $diagnosis, ')
          ..write('diagnosisNotes: $diagnosisNotes, ')
          ..write('researchConsent: $researchConsent, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AssistantMessagesTable extends AssistantMessages
    with TableInfo<$AssistantMessagesTable, AssistantMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AssistantMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cowIdMeta = const VerificationMeta('cowId');
  @override
  late final GeneratedColumn<String> cowId = GeneratedColumn<String>(
    'cow_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cows (id)',
    ),
  );
  static const VerificationMeta _fromUserMeta = const VerificationMeta(
    'fromUser',
  );
  @override
  late final GeneratedColumn<bool> fromUser = GeneratedColumn<bool>(
    'from_user',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("from_user" IN (0, 1))',
    ),
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _withPhotoMeta = const VerificationMeta(
    'withPhoto',
  );
  @override
  late final GeneratedColumn<bool> withPhoto = GeneratedColumn<bool>(
    'with_photo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("with_photo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cowId,
    fromUser,
    body,
    withPhoto,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'assistant_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<AssistantMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('cow_id')) {
      context.handle(
        _cowIdMeta,
        cowId.isAcceptableOrUnknown(data['cow_id']!, _cowIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cowIdMeta);
    }
    if (data.containsKey('from_user')) {
      context.handle(
        _fromUserMeta,
        fromUser.isAcceptableOrUnknown(data['from_user']!, _fromUserMeta),
      );
    } else if (isInserting) {
      context.missing(_fromUserMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('with_photo')) {
      context.handle(
        _withPhotoMeta,
        withPhoto.isAcceptableOrUnknown(data['with_photo']!, _withPhotoMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AssistantMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AssistantMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      cowId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cow_id'],
      )!,
      fromUser: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}from_user'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      withPhoto: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}with_photo'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AssistantMessagesTable createAlias(String alias) {
    return $AssistantMessagesTable(attachedDatabase, alias);
  }
}

class AssistantMessageRow extends DataClass
    implements Insertable<AssistantMessageRow> {
  final String id;
  final String cowId;
  final bool fromUser;
  final String body;

  /// La pregunta llevaba una foto (la foto no se guarda aquí).
  final bool withPhoto;
  final DateTime createdAt;
  const AssistantMessageRow({
    required this.id,
    required this.cowId,
    required this.fromUser,
    required this.body,
    required this.withPhoto,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['cow_id'] = Variable<String>(cowId);
    map['from_user'] = Variable<bool>(fromUser);
    map['body'] = Variable<String>(body);
    map['with_photo'] = Variable<bool>(withPhoto);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AssistantMessagesCompanion toCompanion(bool nullToAbsent) {
    return AssistantMessagesCompanion(
      id: Value(id),
      cowId: Value(cowId),
      fromUser: Value(fromUser),
      body: Value(body),
      withPhoto: Value(withPhoto),
      createdAt: Value(createdAt),
    );
  }

  factory AssistantMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AssistantMessageRow(
      id: serializer.fromJson<String>(json['id']),
      cowId: serializer.fromJson<String>(json['cowId']),
      fromUser: serializer.fromJson<bool>(json['fromUser']),
      body: serializer.fromJson<String>(json['body']),
      withPhoto: serializer.fromJson<bool>(json['withPhoto']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'cowId': serializer.toJson<String>(cowId),
      'fromUser': serializer.toJson<bool>(fromUser),
      'body': serializer.toJson<String>(body),
      'withPhoto': serializer.toJson<bool>(withPhoto),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AssistantMessageRow copyWith({
    String? id,
    String? cowId,
    bool? fromUser,
    String? body,
    bool? withPhoto,
    DateTime? createdAt,
  }) => AssistantMessageRow(
    id: id ?? this.id,
    cowId: cowId ?? this.cowId,
    fromUser: fromUser ?? this.fromUser,
    body: body ?? this.body,
    withPhoto: withPhoto ?? this.withPhoto,
    createdAt: createdAt ?? this.createdAt,
  );
  AssistantMessageRow copyWithCompanion(AssistantMessagesCompanion data) {
    return AssistantMessageRow(
      id: data.id.present ? data.id.value : this.id,
      cowId: data.cowId.present ? data.cowId.value : this.cowId,
      fromUser: data.fromUser.present ? data.fromUser.value : this.fromUser,
      body: data.body.present ? data.body.value : this.body,
      withPhoto: data.withPhoto.present ? data.withPhoto.value : this.withPhoto,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AssistantMessageRow(')
          ..write('id: $id, ')
          ..write('cowId: $cowId, ')
          ..write('fromUser: $fromUser, ')
          ..write('body: $body, ')
          ..write('withPhoto: $withPhoto, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, cowId, fromUser, body, withPhoto, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AssistantMessageRow &&
          other.id == this.id &&
          other.cowId == this.cowId &&
          other.fromUser == this.fromUser &&
          other.body == this.body &&
          other.withPhoto == this.withPhoto &&
          other.createdAt == this.createdAt);
}

class AssistantMessagesCompanion extends UpdateCompanion<AssistantMessageRow> {
  final Value<String> id;
  final Value<String> cowId;
  final Value<bool> fromUser;
  final Value<String> body;
  final Value<bool> withPhoto;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AssistantMessagesCompanion({
    this.id = const Value.absent(),
    this.cowId = const Value.absent(),
    this.fromUser = const Value.absent(),
    this.body = const Value.absent(),
    this.withPhoto = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AssistantMessagesCompanion.insert({
    required String id,
    required String cowId,
    required bool fromUser,
    required String body,
    this.withPhoto = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       cowId = Value(cowId),
       fromUser = Value(fromUser),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<AssistantMessageRow> custom({
    Expression<String>? id,
    Expression<String>? cowId,
    Expression<bool>? fromUser,
    Expression<String>? body,
    Expression<bool>? withPhoto,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cowId != null) 'cow_id': cowId,
      if (fromUser != null) 'from_user': fromUser,
      if (body != null) 'body': body,
      if (withPhoto != null) 'with_photo': withPhoto,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AssistantMessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? cowId,
    Value<bool>? fromUser,
    Value<String>? body,
    Value<bool>? withPhoto,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AssistantMessagesCompanion(
      id: id ?? this.id,
      cowId: cowId ?? this.cowId,
      fromUser: fromUser ?? this.fromUser,
      body: body ?? this.body,
      withPhoto: withPhoto ?? this.withPhoto,
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
    if (cowId.present) {
      map['cow_id'] = Variable<String>(cowId.value);
    }
    if (fromUser.present) {
      map['from_user'] = Variable<bool>(fromUser.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (withPhoto.present) {
      map['with_photo'] = Variable<bool>(withPhoto.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AssistantMessagesCompanion(')
          ..write('id: $id, ')
          ..write('cowId: $cowId, ')
          ..write('fromUser: $fromUser, ')
          ..write('body: $body, ')
          ..write('withPhoto: $withPhoto, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CowsTable cows = $CowsTable(this);
  late final $DailyRecordsTable dailyRecords = $DailyRecordsTable(this);
  late final $InferencesTable inferences = $InferencesTable(this);
  late final $AlertsTable alerts = $AlertsTable(this);
  late final $CowPhotosTable cowPhotos = $CowPhotosTable(this);
  late final $AssistantMessagesTable assistantMessages =
      $AssistantMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cows,
    dailyRecords,
    inferences,
    alerts,
    cowPhotos,
    assistantMessages,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$CowsTableCreateCompanionBuilder = CowsCompanion Function({
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<bool> syncPending,
  Value<bool> isDemo,
  Value<String?> syncError,
  required String id,
  required String tag,
  Value<String?> name,
  Value<String?> breed,
  Value<DateTime?> birthDate,
  Value<int?> calvings,
  required String productionStatus,
  Value<int> rowid,
});
typedef $$CowsTableUpdateCompanionBuilder = CowsCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> syncPending,
  Value<bool> isDemo,
  Value<String?> syncError,
  Value<String> id,
  Value<String> tag,
  Value<String?> name,
  Value<String?> breed,
  Value<DateTime?> birthDate,
  Value<int?> calvings,
  Value<String> productionStatus,
  Value<int> rowid,
});

final class $$CowsTableReferences
    extends BaseReferences<_$AppDatabase, $CowsTable, CowRow> {
  $$CowsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DailyRecordsTable, List<DailyRecordRow>>
  _dailyRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.dailyRecords,
    aliasName: 'cows__id__daily_records__cow_id',
  );

  $$DailyRecordsTableProcessedTableManager get dailyRecordsRefs {
    final manager = $$DailyRecordsTableTableManager(
      $_db,
      $_db.dailyRecords,
    ).filter((f) => f.cowId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_dailyRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InferencesTable, List<InferenceRow>>
  _inferencesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.inferences,
    aliasName: 'cows__id__inferences__cow_id',
  );

  $$InferencesTableProcessedTableManager get inferencesRefs {
    final manager = $$InferencesTableTableManager(
      $_db,
      $_db.inferences,
    ).filter((f) => f.cowId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_inferencesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AlertsTable, List<AlertRow>> _alertsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.alerts,
    aliasName: 'cows__id__alerts__cow_id',
  );

  $$AlertsTableProcessedTableManager get alertsRefs {
    final manager = $$AlertsTableTableManager(
      $_db,
      $_db.alerts,
    ).filter((f) => f.cowId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_alertsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$CowPhotosTable, List<CowPhotoRow>>
  _cowPhotosRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.cowPhotos,
    aliasName: 'cows__id__cow_photos__cow_id',
  );

  $$CowPhotosTableProcessedTableManager get cowPhotosRefs {
    final manager = $$CowPhotosTableTableManager(
      $_db,
      $_db.cowPhotos,
    ).filter((f) => f.cowId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_cowPhotosRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$AssistantMessagesTable, List<AssistantMessageRow>>
  _assistantMessagesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.assistantMessages,
        aliasName: 'cows__id__assistant_messages__cow_id',
      );

  $$AssistantMessagesTableProcessedTableManager get assistantMessagesRefs {
    final manager = $$AssistantMessagesTableTableManager(
      $_db,
      $_db.assistantMessages,
    ).filter((f) => f.cowId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _assistantMessagesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CowsTableFilterComposer extends Composer<_$AppDatabase, $CowsTable> {
  $$CowsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get breed => $composableBuilder(
    column: $table.breed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calvings => $composableBuilder(
    column: $table.calvings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productionStatus => $composableBuilder(
    column: $table.productionStatus,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> dailyRecordsRefs(
    Expression<bool> Function($$DailyRecordsTableFilterComposer f) f,
  ) {
    final $$DailyRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dailyRecords,
      getReferencedColumn: (t) => t.cowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyRecordsTableFilterComposer(
            $db: $db,
            $table: $db.dailyRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> inferencesRefs(
    Expression<bool> Function($$InferencesTableFilterComposer f) f,
  ) {
    final $$InferencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inferences,
      getReferencedColumn: (t) => t.cowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InferencesTableFilterComposer(
            $db: $db,
            $table: $db.inferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> alertsRefs(
    Expression<bool> Function($$AlertsTableFilterComposer f) f,
  ) {
    final $$AlertsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alerts,
      getReferencedColumn: (t) => t.cowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlertsTableFilterComposer(
            $db: $db,
            $table: $db.alerts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> cowPhotosRefs(
    Expression<bool> Function($$CowPhotosTableFilterComposer f) f,
  ) {
    final $$CowPhotosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cowPhotos,
      getReferencedColumn: (t) => t.cowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowPhotosTableFilterComposer(
            $db: $db,
            $table: $db.cowPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> assistantMessagesRefs(
    Expression<bool> Function($$AssistantMessagesTableFilterComposer f) f,
  ) {
    final $$AssistantMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.assistantMessages,
      getReferencedColumn: (t) => t.cowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AssistantMessagesTableFilterComposer(
            $db: $db,
            $table: $db.assistantMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CowsTableOrderingComposer extends Composer<_$AppDatabase, $CowsTable> {
  $$CowsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get breed => $composableBuilder(
    column: $table.breed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calvings => $composableBuilder(
    column: $table.calvings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productionStatus => $composableBuilder(
    column: $table.productionStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CowsTable> {
  $$CowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDemo =>
      $composableBuilder(column: $table.isDemo, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get breed =>
      $composableBuilder(column: $table.breed, builder: (column) => column);

  GeneratedColumn<DateTime> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<int> get calvings =>
      $composableBuilder(column: $table.calvings, builder: (column) => column);

  GeneratedColumn<String> get productionStatus => $composableBuilder(
    column: $table.productionStatus,
    builder: (column) => column,
  );

  Expression<T> dailyRecordsRefs<T extends Object>(
    Expression<T> Function($$DailyRecordsTableAnnotationComposer a) f,
  ) {
    final $$DailyRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.dailyRecords,
      getReferencedColumn: (t) => t.cowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DailyRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.dailyRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> inferencesRefs<T extends Object>(
    Expression<T> Function($$InferencesTableAnnotationComposer a) f,
  ) {
    final $$InferencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.inferences,
      getReferencedColumn: (t) => t.cowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InferencesTableAnnotationComposer(
            $db: $db,
            $table: $db.inferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> alertsRefs<T extends Object>(
    Expression<T> Function($$AlertsTableAnnotationComposer a) f,
  ) {
    final $$AlertsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alerts,
      getReferencedColumn: (t) => t.cowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlertsTableAnnotationComposer(
            $db: $db,
            $table: $db.alerts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> cowPhotosRefs<T extends Object>(
    Expression<T> Function($$CowPhotosTableAnnotationComposer a) f,
  ) {
    final $$CowPhotosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.cowPhotos,
      getReferencedColumn: (t) => t.cowId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowPhotosTableAnnotationComposer(
            $db: $db,
            $table: $db.cowPhotos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> assistantMessagesRefs<T extends Object>(
    Expression<T> Function($$AssistantMessagesTableAnnotationComposer a) f,
  ) {
    final $$AssistantMessagesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.assistantMessages,
          getReferencedColumn: (t) => t.cowId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$AssistantMessagesTableAnnotationComposer(
                $db: $db,
                $table: $db.assistantMessages,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CowsTable,
          CowRow,
          $$CowsTableFilterComposer,
          $$CowsTableOrderingComposer,
          $$CowsTableAnnotationComposer,
          $$CowsTableCreateCompanionBuilder,
          $$CowsTableUpdateCompanionBuilder,
          (CowRow, $$CowsTableReferences),
          CowRow,
          PrefetchHooks Function({
            bool dailyRecordsRefs,
            bool inferencesRefs,
            bool alertsRefs,
            bool cowPhotosRefs,
            bool assistantMessagesRefs,
          })
        > {
  $$CowsTableTableManager(_$AppDatabase db, $CowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<String?> name = const Value.absent(),
                Value<String?> breed = const Value.absent(),
                Value<DateTime?> birthDate = const Value.absent(),
                Value<int?> calvings = const Value.absent(),
                Value<String> productionStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CowsCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                syncPending: syncPending,
                isDemo: isDemo,
                syncError: syncError,
                id: id,
                tag: tag,
                name: name,
                breed: breed,
                birthDate: birthDate,
                calvings: calvings,
                productionStatus: productionStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                required String id,
                required String tag,
                Value<String?> name = const Value.absent(),
                Value<String?> breed = const Value.absent(),
                Value<DateTime?> birthDate = const Value.absent(),
                Value<int?> calvings = const Value.absent(),
                required String productionStatus,
                Value<int> rowid = const Value.absent(),
              }) => CowsCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                syncPending: syncPending,
                isDemo: isDemo,
                syncError: syncError,
                id: id,
                tag: tag,
                name: name,
                breed: breed,
                birthDate: birthDate,
                calvings: calvings,
                productionStatus: productionStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CowsTable, CowRow>(table),
                  $$CowsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                dailyRecordsRefs = false,
                inferencesRefs = false,
                alertsRefs = false,
                cowPhotosRefs = false,
                assistantMessagesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (dailyRecordsRefs) db.dailyRecords,
                    if (inferencesRefs) db.inferences,
                    if (alertsRefs) db.alerts,
                    if (cowPhotosRefs) db.cowPhotos,
                    if (assistantMessagesRefs) db.assistantMessages,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (dailyRecordsRefs)
                        await $_getPrefetchedDataByColumns<
                          CowRow,
                          $CowsTable,
                          DailyRecordRow,
                          $DailyRecordsTable
                        >(
                          currentTable: table,
                          referencedTable: $$CowsTableReferences
                              ._dailyRecordsRefsTable(db),
                          managerFromTypedResult: (p0) => $$CowsTableReferences(
                            db,
                            table,
                            p0,
                          ).dailyRecordsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'cow_id',
                          typedResults: items,
                        ),
                      if (inferencesRefs)
                        await $_getPrefetchedDataByColumns<
                          CowRow,
                          $CowsTable,
                          InferenceRow,
                          $InferencesTable
                        >(
                          currentTable: table,
                          referencedTable: $$CowsTableReferences
                              ._inferencesRefsTable(db),
                          managerFromTypedResult: (p0) => $$CowsTableReferences(
                            db,
                            table,
                            p0,
                          ).inferencesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'cow_id',
                          typedResults: items,
                        ),
                      if (alertsRefs)
                        await $_getPrefetchedDataByColumns<
                          CowRow,
                          $CowsTable,
                          AlertRow,
                          $AlertsTable
                        >(
                          currentTable: table,
                          referencedTable: $$CowsTableReferences
                              ._alertsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CowsTableReferences(db, table, p0).alertsRefs,
                          currentColumn: 'id',
                          referencedColumn: 'cow_id',
                          typedResults: items,
                        ),
                      if (cowPhotosRefs)
                        await $_getPrefetchedDataByColumns<
                          CowRow,
                          $CowsTable,
                          CowPhotoRow,
                          $CowPhotosTable
                        >(
                          currentTable: table,
                          referencedTable: $$CowsTableReferences
                              ._cowPhotosRefsTable(db),
                          managerFromTypedResult: (p0) => $$CowsTableReferences(
                            db,
                            table,
                            p0,
                          ).cowPhotosRefs,
                          currentColumn: 'id',
                          referencedColumn: 'cow_id',
                          typedResults: items,
                        ),
                      if (assistantMessagesRefs)
                        await $_getPrefetchedDataByColumns<
                          CowRow,
                          $CowsTable,
                          AssistantMessageRow,
                          $AssistantMessagesTable
                        >(
                          currentTable: table,
                          referencedTable: $$CowsTableReferences
                              ._assistantMessagesRefsTable(db),
                          managerFromTypedResult: (p0) => $$CowsTableReferences(
                            db,
                            table,
                            p0,
                          ).assistantMessagesRefs,
                          currentColumn: 'id',
                          referencedColumn: 'cow_id',
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CowsTable,
      CowRow,
      $$CowsTableFilterComposer,
      $$CowsTableOrderingComposer,
      $$CowsTableAnnotationComposer,
      $$CowsTableCreateCompanionBuilder,
      $$CowsTableUpdateCompanionBuilder,
      (CowRow, $$CowsTableReferences),
      CowRow,
      PrefetchHooks Function({
        bool dailyRecordsRefs,
        bool inferencesRefs,
        bool alertsRefs,
        bool cowPhotosRefs,
        bool assistantMessagesRefs,
      })
    >;
typedef $$DailyRecordsTableCreateCompanionBuilder =
    DailyRecordsCompanion Function({
      required DateTime updatedAt,
      Value<bool> deleted,
      Value<bool> syncPending,
      Value<bool> isDemo,
      Value<String?> syncError,
      required String id,
      required String cowId,
      required String recordDate,
      Value<double?> temperatureC,
      Value<double?> milkL,
      Value<double?> feedKg,
      Value<bool> udderSwelling,
      Value<bool> abnormalMilk,
      Value<bool> udderPain,
      Value<bool> lethargy,
      Value<bool> udderRedness,
      Value<bool> udderHeat,
      Value<bool?> ateNormally,
      Value<bool?> milkDrop,
      Value<String?> notes,
      Value<int> rowid,
    });
typedef $$DailyRecordsTableUpdateCompanionBuilder =
    DailyRecordsCompanion Function({
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<bool> syncPending,
      Value<bool> isDemo,
      Value<String?> syncError,
      Value<String> id,
      Value<String> cowId,
      Value<String> recordDate,
      Value<double?> temperatureC,
      Value<double?> milkL,
      Value<double?> feedKg,
      Value<bool> udderSwelling,
      Value<bool> abnormalMilk,
      Value<bool> udderPain,
      Value<bool> lethargy,
      Value<bool> udderRedness,
      Value<bool> udderHeat,
      Value<bool?> ateNormally,
      Value<bool?> milkDrop,
      Value<String?> notes,
      Value<int> rowid,
    });

final class $$DailyRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $DailyRecordsTable, DailyRecordRow> {
  $$DailyRecordsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CowsTable _cowIdTable(_$AppDatabase db) =>
      db.cows.createAlias('daily_records__cow_id__cows__id');

  $$CowsTableProcessedTableManager get cowId {
    final $_column = $_itemColumn<String>('cow_id')!;

    final manager = $$CowsTableTableManager(
      $_db,
      $_db.cows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cowIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DailyRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyRecordsTable> {
  $$DailyRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get milkL => $composableBuilder(
    column: $table.milkL,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get feedKg => $composableBuilder(
    column: $table.feedKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get udderSwelling => $composableBuilder(
    column: $table.udderSwelling,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get abnormalMilk => $composableBuilder(
    column: $table.abnormalMilk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get udderPain => $composableBuilder(
    column: $table.udderPain,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get lethargy => $composableBuilder(
    column: $table.lethargy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get udderRedness => $composableBuilder(
    column: $table.udderRedness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get udderHeat => $composableBuilder(
    column: $table.udderHeat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get ateNormally => $composableBuilder(
    column: $table.ateNormally,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get milkDrop => $composableBuilder(
    column: $table.milkDrop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$CowsTableFilterComposer get cowId {
    final $$CowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableFilterComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyRecordsTable> {
  $$DailyRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get milkL => $composableBuilder(
    column: $table.milkL,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get feedKg => $composableBuilder(
    column: $table.feedKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get udderSwelling => $composableBuilder(
    column: $table.udderSwelling,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get abnormalMilk => $composableBuilder(
    column: $table.abnormalMilk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get udderPain => $composableBuilder(
    column: $table.udderPain,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get lethargy => $composableBuilder(
    column: $table.lethargy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get udderRedness => $composableBuilder(
    column: $table.udderRedness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get udderHeat => $composableBuilder(
    column: $table.udderHeat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get ateNormally => $composableBuilder(
    column: $table.ateNormally,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get milkDrop => $composableBuilder(
    column: $table.milkDrop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$CowsTableOrderingComposer get cowId {
    final $$CowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableOrderingComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyRecordsTable> {
  $$DailyRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDemo =>
      $composableBuilder(column: $table.isDemo, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordDate => $composableBuilder(
    column: $table.recordDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get temperatureC => $composableBuilder(
    column: $table.temperatureC,
    builder: (column) => column,
  );

  GeneratedColumn<double> get milkL =>
      $composableBuilder(column: $table.milkL, builder: (column) => column);

  GeneratedColumn<double> get feedKg =>
      $composableBuilder(column: $table.feedKg, builder: (column) => column);

  GeneratedColumn<bool> get udderSwelling => $composableBuilder(
    column: $table.udderSwelling,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get abnormalMilk => $composableBuilder(
    column: $table.abnormalMilk,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get udderPain =>
      $composableBuilder(column: $table.udderPain, builder: (column) => column);

  GeneratedColumn<bool> get lethargy =>
      $composableBuilder(column: $table.lethargy, builder: (column) => column);

  GeneratedColumn<bool> get udderRedness => $composableBuilder(
    column: $table.udderRedness,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get udderHeat =>
      $composableBuilder(column: $table.udderHeat, builder: (column) => column);

  GeneratedColumn<bool> get ateNormally => $composableBuilder(
    column: $table.ateNormally,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get milkDrop =>
      $composableBuilder(column: $table.milkDrop, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$CowsTableAnnotationComposer get cowId {
    final $$CowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableAnnotationComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DailyRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyRecordsTable,
          DailyRecordRow,
          $$DailyRecordsTableFilterComposer,
          $$DailyRecordsTableOrderingComposer,
          $$DailyRecordsTableAnnotationComposer,
          $$DailyRecordsTableCreateCompanionBuilder,
          $$DailyRecordsTableUpdateCompanionBuilder,
          (DailyRecordRow, $$DailyRecordsTableReferences),
          DailyRecordRow,
          PrefetchHooks Function({bool cowId})
        > {
  $$DailyRecordsTableTableManager(_$AppDatabase db, $DailyRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> cowId = const Value.absent(),
                Value<String> recordDate = const Value.absent(),
                Value<double?> temperatureC = const Value.absent(),
                Value<double?> milkL = const Value.absent(),
                Value<double?> feedKg = const Value.absent(),
                Value<bool> udderSwelling = const Value.absent(),
                Value<bool> abnormalMilk = const Value.absent(),
                Value<bool> udderPain = const Value.absent(),
                Value<bool> lethargy = const Value.absent(),
                Value<bool> udderRedness = const Value.absent(),
                Value<bool> udderHeat = const Value.absent(),
                Value<bool?> ateNormally = const Value.absent(),
                Value<bool?> milkDrop = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyRecordsCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                syncPending: syncPending,
                isDemo: isDemo,
                syncError: syncError,
                id: id,
                cowId: cowId,
                recordDate: recordDate,
                temperatureC: temperatureC,
                milkL: milkL,
                feedKg: feedKg,
                udderSwelling: udderSwelling,
                abnormalMilk: abnormalMilk,
                udderPain: udderPain,
                lethargy: lethargy,
                udderRedness: udderRedness,
                udderHeat: udderHeat,
                ateNormally: ateNormally,
                milkDrop: milkDrop,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                required String id,
                required String cowId,
                required String recordDate,
                Value<double?> temperatureC = const Value.absent(),
                Value<double?> milkL = const Value.absent(),
                Value<double?> feedKg = const Value.absent(),
                Value<bool> udderSwelling = const Value.absent(),
                Value<bool> abnormalMilk = const Value.absent(),
                Value<bool> udderPain = const Value.absent(),
                Value<bool> lethargy = const Value.absent(),
                Value<bool> udderRedness = const Value.absent(),
                Value<bool> udderHeat = const Value.absent(),
                Value<bool?> ateNormally = const Value.absent(),
                Value<bool?> milkDrop = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DailyRecordsCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                syncPending: syncPending,
                isDemo: isDemo,
                syncError: syncError,
                id: id,
                cowId: cowId,
                recordDate: recordDate,
                temperatureC: temperatureC,
                milkL: milkL,
                feedKg: feedKg,
                udderSwelling: udderSwelling,
                abnormalMilk: abnormalMilk,
                udderPain: udderPain,
                lethargy: lethargy,
                udderRedness: udderRedness,
                udderHeat: udderHeat,
                ateNormally: ateNormally,
                milkDrop: milkDrop,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DailyRecordsTable, DailyRecordRow>(table),
                  $$DailyRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cowId = false}) {
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
                    if (cowId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cowId,
                        referencedTable: $$DailyRecordsTableReferences
                            ._cowIdTable(db),
                        referencedColumn: $$DailyRecordsTableReferences
                            ._cowIdTable(db)
                            .id,
                      ) as T;
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

typedef $$DailyRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyRecordsTable,
      DailyRecordRow,
      $$DailyRecordsTableFilterComposer,
      $$DailyRecordsTableOrderingComposer,
      $$DailyRecordsTableAnnotationComposer,
      $$DailyRecordsTableCreateCompanionBuilder,
      $$DailyRecordsTableUpdateCompanionBuilder,
      (DailyRecordRow, $$DailyRecordsTableReferences),
      DailyRecordRow,
      PrefetchHooks Function({bool cowId})
    >;
typedef $$InferencesTableCreateCompanionBuilder = InferencesCompanion Function({
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<bool> syncPending,
  Value<bool> isDemo,
  Value<String?> syncError,
  required String id,
  required String cowId,
  required String windowEndDate,
  Value<double?> probability,
  Value<int?> symptomScore,
  Value<String?> cause,
  required String riskLevel,
  required String modelVersion,
  Value<int> rowid,
});
typedef $$InferencesTableUpdateCompanionBuilder = InferencesCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> syncPending,
  Value<bool> isDemo,
  Value<String?> syncError,
  Value<String> id,
  Value<String> cowId,
  Value<String> windowEndDate,
  Value<double?> probability,
  Value<int?> symptomScore,
  Value<String?> cause,
  Value<String> riskLevel,
  Value<String> modelVersion,
  Value<int> rowid,
});

final class $$InferencesTableReferences
    extends BaseReferences<_$AppDatabase, $InferencesTable, InferenceRow> {
  $$InferencesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CowsTable _cowIdTable(_$AppDatabase db) =>
      db.cows.createAlias('inferences__cow_id__cows__id');

  $$CowsTableProcessedTableManager get cowId {
    final $_column = $_itemColumn<String>('cow_id')!;

    final manager = $$CowsTableTableManager(
      $_db,
      $_db.cows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cowIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$AlertsTable, List<AlertRow>> _alertsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.alerts,
    aliasName: 'inferences__id__alerts__inference_id',
  );

  $$AlertsTableProcessedTableManager get alertsRefs {
    final manager = $$AlertsTableTableManager(
      $_db,
      $_db.alerts,
    ).filter((f) => f.inferenceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_alertsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$InferencesTableFilterComposer
    extends Composer<_$AppDatabase, $InferencesTable> {
  $$InferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get windowEndDate => $composableBuilder(
    column: $table.windowEndDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get probability => $composableBuilder(
    column: $table.probability,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get symptomScore => $composableBuilder(
    column: $table.symptomScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cause => $composableBuilder(
    column: $table.cause,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get riskLevel => $composableBuilder(
    column: $table.riskLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$CowsTableFilterComposer get cowId {
    final $$CowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableFilterComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> alertsRefs(
    Expression<bool> Function($$AlertsTableFilterComposer f) f,
  ) {
    final $$AlertsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alerts,
      getReferencedColumn: (t) => t.inferenceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlertsTableFilterComposer(
            $db: $db,
            $table: $db.alerts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $InferencesTable> {
  $$InferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get windowEndDate => $composableBuilder(
    column: $table.windowEndDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get probability => $composableBuilder(
    column: $table.probability,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get symptomScore => $composableBuilder(
    column: $table.symptomScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cause => $composableBuilder(
    column: $table.cause,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get riskLevel => $composableBuilder(
    column: $table.riskLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$CowsTableOrderingComposer get cowId {
    final $$CowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableOrderingComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $InferencesTable> {
  $$InferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDemo =>
      $composableBuilder(column: $table.isDemo, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get windowEndDate => $composableBuilder(
    column: $table.windowEndDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get probability => $composableBuilder(
    column: $table.probability,
    builder: (column) => column,
  );

  GeneratedColumn<int> get symptomScore => $composableBuilder(
    column: $table.symptomScore,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cause =>
      $composableBuilder(column: $table.cause, builder: (column) => column);

  GeneratedColumn<String> get riskLevel =>
      $composableBuilder(column: $table.riskLevel, builder: (column) => column);

  GeneratedColumn<String> get modelVersion => $composableBuilder(
    column: $table.modelVersion,
    builder: (column) => column,
  );

  $$CowsTableAnnotationComposer get cowId {
    final $$CowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableAnnotationComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> alertsRefs<T extends Object>(
    Expression<T> Function($$AlertsTableAnnotationComposer a) f,
  ) {
    final $$AlertsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.alerts,
      getReferencedColumn: (t) => t.inferenceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$AlertsTableAnnotationComposer(
            $db: $db,
            $table: $db.alerts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$InferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InferencesTable,
          InferenceRow,
          $$InferencesTableFilterComposer,
          $$InferencesTableOrderingComposer,
          $$InferencesTableAnnotationComposer,
          $$InferencesTableCreateCompanionBuilder,
          $$InferencesTableUpdateCompanionBuilder,
          (InferenceRow, $$InferencesTableReferences),
          InferenceRow,
          PrefetchHooks Function({bool cowId, bool alertsRefs})
        > {
  $$InferencesTableTableManager(_$AppDatabase db, $InferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> cowId = const Value.absent(),
                Value<String> windowEndDate = const Value.absent(),
                Value<double?> probability = const Value.absent(),
                Value<int?> symptomScore = const Value.absent(),
                Value<String?> cause = const Value.absent(),
                Value<String> riskLevel = const Value.absent(),
                Value<String> modelVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InferencesCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                syncPending: syncPending,
                isDemo: isDemo,
                syncError: syncError,
                id: id,
                cowId: cowId,
                windowEndDate: windowEndDate,
                probability: probability,
                symptomScore: symptomScore,
                cause: cause,
                riskLevel: riskLevel,
                modelVersion: modelVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                required String id,
                required String cowId,
                required String windowEndDate,
                Value<double?> probability = const Value.absent(),
                Value<int?> symptomScore = const Value.absent(),
                Value<String?> cause = const Value.absent(),
                required String riskLevel,
                required String modelVersion,
                Value<int> rowid = const Value.absent(),
              }) => InferencesCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                syncPending: syncPending,
                isDemo: isDemo,
                syncError: syncError,
                id: id,
                cowId: cowId,
                windowEndDate: windowEndDate,
                probability: probability,
                symptomScore: symptomScore,
                cause: cause,
                riskLevel: riskLevel,
                modelVersion: modelVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InferencesTable, InferenceRow>(table),
                  $$InferencesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cowId = false, alertsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (alertsRefs) db.alerts],
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
                    if (cowId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cowId,
                        referencedTable: $$InferencesTableReferences
                            ._cowIdTable(db),
                        referencedColumn: $$InferencesTableReferences
                            ._cowIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (alertsRefs)
                    await $_getPrefetchedDataByColumns<
                      InferenceRow,
                      $InferencesTable,
                      AlertRow,
                      $AlertsTable
                    >(
                      currentTable: table,
                      referencedTable: $$InferencesTableReferences
                          ._alertsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$InferencesTableReferences(db, table, p0).alertsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'inference_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$InferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InferencesTable,
      InferenceRow,
      $$InferencesTableFilterComposer,
      $$InferencesTableOrderingComposer,
      $$InferencesTableAnnotationComposer,
      $$InferencesTableCreateCompanionBuilder,
      $$InferencesTableUpdateCompanionBuilder,
      (InferenceRow, $$InferencesTableReferences),
      InferenceRow,
      PrefetchHooks Function({bool cowId, bool alertsRefs})
    >;
typedef $$AlertsTableCreateCompanionBuilder = AlertsCompanion Function({
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<bool> syncPending,
  Value<bool> isDemo,
  Value<String?> syncError,
  required String id,
  required String cowId,
  Value<String?> inferenceId,
  required String riskLevel,
  Value<bool> attended,
  Value<DateTime?> attendedAt,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$AlertsTableUpdateCompanionBuilder = AlertsCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> syncPending,
  Value<bool> isDemo,
  Value<String?> syncError,
  Value<String> id,
  Value<String> cowId,
  Value<String?> inferenceId,
  Value<String> riskLevel,
  Value<bool> attended,
  Value<DateTime?> attendedAt,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$AlertsTableReferences
    extends BaseReferences<_$AppDatabase, $AlertsTable, AlertRow> {
  $$AlertsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CowsTable _cowIdTable(_$AppDatabase db) =>
      db.cows.createAlias('alerts__cow_id__cows__id');

  $$CowsTableProcessedTableManager get cowId {
    final $_column = $_itemColumn<String>('cow_id')!;

    final manager = $$CowsTableTableManager(
      $_db,
      $_db.cows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cowIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $InferencesTable _inferenceIdTable(_$AppDatabase db) =>
      db.inferences.createAlias('alerts__inference_id__inferences__id');

  $$InferencesTableProcessedTableManager? get inferenceId {
    final $_column = $_itemColumn<String>('inference_id');
    if ($_column == null) return null;
    final manager = $$InferencesTableTableManager(
      $_db,
      $_db.inferences,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_inferenceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AlertsTableFilterComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get riskLevel => $composableBuilder(
    column: $table.riskLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get attended => $composableBuilder(
    column: $table.attended,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get attendedAt => $composableBuilder(
    column: $table.attendedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CowsTableFilterComposer get cowId {
    final $$CowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableFilterComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InferencesTableFilterComposer get inferenceId {
    final $$InferencesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.inferenceId,
      referencedTable: $db.inferences,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InferencesTableFilterComposer(
            $db: $db,
            $table: $db.inferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlertsTableOrderingComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get riskLevel => $composableBuilder(
    column: $table.riskLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get attended => $composableBuilder(
    column: $table.attended,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get attendedAt => $composableBuilder(
    column: $table.attendedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CowsTableOrderingComposer get cowId {
    final $$CowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableOrderingComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InferencesTableOrderingComposer get inferenceId {
    final $$InferencesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.inferenceId,
      referencedTable: $db.inferences,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InferencesTableOrderingComposer(
            $db: $db,
            $table: $db.inferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlertsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AlertsTable> {
  $$AlertsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDemo =>
      $composableBuilder(column: $table.isDemo, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get riskLevel =>
      $composableBuilder(column: $table.riskLevel, builder: (column) => column);

  GeneratedColumn<bool> get attended =>
      $composableBuilder(column: $table.attended, builder: (column) => column);

  GeneratedColumn<DateTime> get attendedAt => $composableBuilder(
    column: $table.attendedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CowsTableAnnotationComposer get cowId {
    final $$CowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableAnnotationComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$InferencesTableAnnotationComposer get inferenceId {
    final $$InferencesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.inferenceId,
      referencedTable: $db.inferences,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InferencesTableAnnotationComposer(
            $db: $db,
            $table: $db.inferences,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AlertsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AlertsTable,
          AlertRow,
          $$AlertsTableFilterComposer,
          $$AlertsTableOrderingComposer,
          $$AlertsTableAnnotationComposer,
          $$AlertsTableCreateCompanionBuilder,
          $$AlertsTableUpdateCompanionBuilder,
          (AlertRow, $$AlertsTableReferences),
          AlertRow,
          PrefetchHooks Function({bool cowId, bool inferenceId})
        > {
  $$AlertsTableTableManager(_$AppDatabase db, $AlertsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AlertsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AlertsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AlertsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> cowId = const Value.absent(),
                Value<String?> inferenceId = const Value.absent(),
                Value<String> riskLevel = const Value.absent(),
                Value<bool> attended = const Value.absent(),
                Value<DateTime?> attendedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AlertsCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                syncPending: syncPending,
                isDemo: isDemo,
                syncError: syncError,
                id: id,
                cowId: cowId,
                inferenceId: inferenceId,
                riskLevel: riskLevel,
                attended: attended,
                attendedAt: attendedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                required String id,
                required String cowId,
                Value<String?> inferenceId = const Value.absent(),
                required String riskLevel,
                Value<bool> attended = const Value.absent(),
                Value<DateTime?> attendedAt = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AlertsCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                syncPending: syncPending,
                isDemo: isDemo,
                syncError: syncError,
                id: id,
                cowId: cowId,
                inferenceId: inferenceId,
                riskLevel: riskLevel,
                attended: attended,
                attendedAt: attendedAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AlertsTable, AlertRow>(table),
                  $$AlertsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cowId = false, inferenceId = false}) {
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
                    if (cowId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cowId,
                        referencedTable: $$AlertsTableReferences._cowIdTable(
                          db,
                        ),
                        referencedColumn: $$AlertsTableReferences
                            ._cowIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (inferenceId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.inferenceId,
                        referencedTable: $$AlertsTableReferences
                            ._inferenceIdTable(db),
                        referencedColumn: $$AlertsTableReferences
                            ._inferenceIdTable(db)
                            .id,
                      ) as T;
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

typedef $$AlertsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AlertsTable,
      AlertRow,
      $$AlertsTableFilterComposer,
      $$AlertsTableOrderingComposer,
      $$AlertsTableAnnotationComposer,
      $$AlertsTableCreateCompanionBuilder,
      $$AlertsTableUpdateCompanionBuilder,
      (AlertRow, $$AlertsTableReferences),
      AlertRow,
      PrefetchHooks Function({bool cowId, bool inferenceId})
    >;
typedef $$CowPhotosTableCreateCompanionBuilder = CowPhotosCompanion Function({
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<bool> syncPending,
  Value<bool> isDemo,
  Value<String?> syncError,
  required String id,
  required String cowId,
  required String takenOn,
  required String fileName,
  required int sizeBytes,
  Value<bool> imageUploaded,
  Value<String?> vetConfirmed,
  Value<String?> diagnosis,
  Value<String?> diagnosisNotes,
  Value<bool> researchConsent,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$CowPhotosTableUpdateCompanionBuilder = CowPhotosCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> syncPending,
  Value<bool> isDemo,
  Value<String?> syncError,
  Value<String> id,
  Value<String> cowId,
  Value<String> takenOn,
  Value<String> fileName,
  Value<int> sizeBytes,
  Value<bool> imageUploaded,
  Value<String?> vetConfirmed,
  Value<String?> diagnosis,
  Value<String?> diagnosisNotes,
  Value<bool> researchConsent,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

final class $$CowPhotosTableReferences
    extends BaseReferences<_$AppDatabase, $CowPhotosTable, CowPhotoRow> {
  $$CowPhotosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CowsTable _cowIdTable(_$AppDatabase db) =>
      db.cows.createAlias('cow_photos__cow_id__cows__id');

  $$CowsTableProcessedTableManager get cowId {
    final $_column = $_itemColumn<String>('cow_id')!;

    final manager = $$CowsTableTableManager(
      $_db,
      $_db.cows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cowIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CowPhotosTableFilterComposer
    extends Composer<_$AppDatabase, $CowPhotosTable> {
  $$CowPhotosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get takenOn => $composableBuilder(
    column: $table.takenOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get imageUploaded => $composableBuilder(
    column: $table.imageUploaded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vetConfirmed => $composableBuilder(
    column: $table.vetConfirmed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diagnosis => $composableBuilder(
    column: $table.diagnosis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get diagnosisNotes => $composableBuilder(
    column: $table.diagnosisNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get researchConsent => $composableBuilder(
    column: $table.researchConsent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CowsTableFilterComposer get cowId {
    final $$CowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableFilterComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CowPhotosTableOrderingComposer
    extends Composer<_$AppDatabase, $CowPhotosTable> {
  $$CowPhotosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDemo => $composableBuilder(
    column: $table.isDemo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncError => $composableBuilder(
    column: $table.syncError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get takenOn => $composableBuilder(
    column: $table.takenOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get imageUploaded => $composableBuilder(
    column: $table.imageUploaded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vetConfirmed => $composableBuilder(
    column: $table.vetConfirmed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diagnosis => $composableBuilder(
    column: $table.diagnosis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get diagnosisNotes => $composableBuilder(
    column: $table.diagnosisNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get researchConsent => $composableBuilder(
    column: $table.researchConsent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CowsTableOrderingComposer get cowId {
    final $$CowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableOrderingComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CowPhotosTableAnnotationComposer
    extends Composer<_$AppDatabase, $CowPhotosTable> {
  $$CowPhotosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get syncPending => $composableBuilder(
    column: $table.syncPending,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDemo =>
      $composableBuilder(column: $table.isDemo, builder: (column) => column);

  GeneratedColumn<String> get syncError =>
      $composableBuilder(column: $table.syncError, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get takenOn =>
      $composableBuilder(column: $table.takenOn, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<bool> get imageUploaded => $composableBuilder(
    column: $table.imageUploaded,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vetConfirmed => $composableBuilder(
    column: $table.vetConfirmed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get diagnosis =>
      $composableBuilder(column: $table.diagnosis, builder: (column) => column);

  GeneratedColumn<String> get diagnosisNotes => $composableBuilder(
    column: $table.diagnosisNotes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get researchConsent => $composableBuilder(
    column: $table.researchConsent,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CowsTableAnnotationComposer get cowId {
    final $$CowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableAnnotationComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CowPhotosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CowPhotosTable,
          CowPhotoRow,
          $$CowPhotosTableFilterComposer,
          $$CowPhotosTableOrderingComposer,
          $$CowPhotosTableAnnotationComposer,
          $$CowPhotosTableCreateCompanionBuilder,
          $$CowPhotosTableUpdateCompanionBuilder,
          (CowPhotoRow, $$CowPhotosTableReferences),
          CowPhotoRow,
          PrefetchHooks Function({bool cowId})
        > {
  $$CowPhotosTableTableManager(_$AppDatabase db, $CowPhotosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CowPhotosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CowPhotosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CowPhotosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> cowId = const Value.absent(),
                Value<String> takenOn = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<bool> imageUploaded = const Value.absent(),
                Value<String?> vetConfirmed = const Value.absent(),
                Value<String?> diagnosis = const Value.absent(),
                Value<String?> diagnosisNotes = const Value.absent(),
                Value<bool> researchConsent = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CowPhotosCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                syncPending: syncPending,
                isDemo: isDemo,
                syncError: syncError,
                id: id,
                cowId: cowId,
                takenOn: takenOn,
                fileName: fileName,
                sizeBytes: sizeBytes,
                imageUploaded: imageUploaded,
                vetConfirmed: vetConfirmed,
                diagnosis: diagnosis,
                diagnosisNotes: diagnosisNotes,
                researchConsent: researchConsent,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<bool> syncPending = const Value.absent(),
                Value<bool> isDemo = const Value.absent(),
                Value<String?> syncError = const Value.absent(),
                required String id,
                required String cowId,
                required String takenOn,
                required String fileName,
                required int sizeBytes,
                Value<bool> imageUploaded = const Value.absent(),
                Value<String?> vetConfirmed = const Value.absent(),
                Value<String?> diagnosis = const Value.absent(),
                Value<String?> diagnosisNotes = const Value.absent(),
                Value<bool> researchConsent = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => CowPhotosCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                syncPending: syncPending,
                isDemo: isDemo,
                syncError: syncError,
                id: id,
                cowId: cowId,
                takenOn: takenOn,
                fileName: fileName,
                sizeBytes: sizeBytes,
                imageUploaded: imageUploaded,
                vetConfirmed: vetConfirmed,
                diagnosis: diagnosis,
                diagnosisNotes: diagnosisNotes,
                researchConsent: researchConsent,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CowPhotosTable, CowPhotoRow>(table),
                  $$CowPhotosTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cowId = false}) {
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
                    if (cowId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cowId,
                        referencedTable: $$CowPhotosTableReferences._cowIdTable(
                          db,
                        ),
                        referencedColumn: $$CowPhotosTableReferences
                            ._cowIdTable(db)
                            .id,
                      ) as T;
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

typedef $$CowPhotosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CowPhotosTable,
      CowPhotoRow,
      $$CowPhotosTableFilterComposer,
      $$CowPhotosTableOrderingComposer,
      $$CowPhotosTableAnnotationComposer,
      $$CowPhotosTableCreateCompanionBuilder,
      $$CowPhotosTableUpdateCompanionBuilder,
      (CowPhotoRow, $$CowPhotosTableReferences),
      CowPhotoRow,
      PrefetchHooks Function({bool cowId})
    >;
typedef $$AssistantMessagesTableCreateCompanionBuilder =
    AssistantMessagesCompanion Function({
      required String id,
      required String cowId,
      required bool fromUser,
      required String body,
      Value<bool> withPhoto,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AssistantMessagesTableUpdateCompanionBuilder =
    AssistantMessagesCompanion Function({
      Value<String> id,
      Value<String> cowId,
      Value<bool> fromUser,
      Value<String> body,
      Value<bool> withPhoto,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$AssistantMessagesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $AssistantMessagesTable,
          AssistantMessageRow
        > {
  $$AssistantMessagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CowsTable _cowIdTable(_$AppDatabase db) =>
      db.cows.createAlias('assistant_messages__cow_id__cows__id');

  $$CowsTableProcessedTableManager get cowId {
    final $_column = $_itemColumn<String>('cow_id')!;

    final manager = $$CowsTableTableManager(
      $_db,
      $_db.cows,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cowIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$AssistantMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $AssistantMessagesTable> {
  $$AssistantMessagesTableFilterComposer({
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

  ColumnFilters<bool> get fromUser => $composableBuilder(
    column: $table.fromUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get withPhoto => $composableBuilder(
    column: $table.withPhoto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CowsTableFilterComposer get cowId {
    final $$CowsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableFilterComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssistantMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $AssistantMessagesTable> {
  $$AssistantMessagesTableOrderingComposer({
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

  ColumnOrderings<bool> get fromUser => $composableBuilder(
    column: $table.fromUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get withPhoto => $composableBuilder(
    column: $table.withPhoto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CowsTableOrderingComposer get cowId {
    final $$CowsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableOrderingComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssistantMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AssistantMessagesTable> {
  $$AssistantMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get fromUser =>
      $composableBuilder(column: $table.fromUser, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<bool> get withPhoto =>
      $composableBuilder(column: $table.withPhoto, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CowsTableAnnotationComposer get cowId {
    final $$CowsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cowId,
      referencedTable: $db.cows,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CowsTableAnnotationComposer(
            $db: $db,
            $table: $db.cows,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$AssistantMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AssistantMessagesTable,
          AssistantMessageRow,
          $$AssistantMessagesTableFilterComposer,
          $$AssistantMessagesTableOrderingComposer,
          $$AssistantMessagesTableAnnotationComposer,
          $$AssistantMessagesTableCreateCompanionBuilder,
          $$AssistantMessagesTableUpdateCompanionBuilder,
          (AssistantMessageRow, $$AssistantMessagesTableReferences),
          AssistantMessageRow,
          PrefetchHooks Function({bool cowId})
        > {
  $$AssistantMessagesTableTableManager(
    _$AppDatabase db,
    $AssistantMessagesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AssistantMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AssistantMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AssistantMessagesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> cowId = const Value.absent(),
                Value<bool> fromUser = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<bool> withPhoto = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AssistantMessagesCompanion(
                id: id,
                cowId: cowId,
                fromUser: fromUser,
                body: body,
                withPhoto: withPhoto,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String cowId,
                required bool fromUser,
                required String body,
                Value<bool> withPhoto = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AssistantMessagesCompanion.insert(
                id: id,
                cowId: cowId,
                fromUser: fromUser,
                body: body,
                withPhoto: withPhoto,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AssistantMessagesTable, AssistantMessageRow>(
                    table,
                  ),
                  $$AssistantMessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cowId = false}) {
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
                    if (cowId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cowId,
                        referencedTable: $$AssistantMessagesTableReferences
                            ._cowIdTable(db),
                        referencedColumn: $$AssistantMessagesTableReferences
                            ._cowIdTable(db)
                            .id,
                      ) as T;
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

typedef $$AssistantMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AssistantMessagesTable,
      AssistantMessageRow,
      $$AssistantMessagesTableFilterComposer,
      $$AssistantMessagesTableOrderingComposer,
      $$AssistantMessagesTableAnnotationComposer,
      $$AssistantMessagesTableCreateCompanionBuilder,
      $$AssistantMessagesTableUpdateCompanionBuilder,
      (AssistantMessageRow, $$AssistantMessagesTableReferences),
      AssistantMessageRow,
      PrefetchHooks Function({bool cowId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CowsTableTableManager get cows => $$CowsTableTableManager(_db, _db.cows);
  $$DailyRecordsTableTableManager get dailyRecords =>
      $$DailyRecordsTableTableManager(_db, _db.dailyRecords);
  $$InferencesTableTableManager get inferences =>
      $$InferencesTableTableManager(_db, _db.inferences);
  $$AlertsTableTableManager get alerts =>
      $$AlertsTableTableManager(_db, _db.alerts);
  $$CowPhotosTableTableManager get cowPhotos =>
      $$CowPhotosTableTableManager(_db, _db.cowPhotos);
  $$AssistantMessagesTableTableManager get assistantMessages =>
      $$AssistantMessagesTableTableManager(_db, _db.assistantMessages);
}
