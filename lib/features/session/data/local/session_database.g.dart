// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_database.dart';

// ignore_for_file: type=lint
class $LocalSessionsTable extends LocalSessions
    with TableInfo<$LocalSessionsTable, LocalSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _partnerIdMeta = const VerificationMeta(
    'partnerId',
  );
  @override
  late final GeneratedColumn<String> partnerId = GeneratedColumn<String>(
    'partner_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partnerNameMeta = const VerificationMeta(
    'partnerName',
  );
  @override
  late final GeneratedColumn<String> partnerName = GeneratedColumn<String>(
    'partner_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _threadIdMeta = const VerificationMeta(
    'threadId',
  );
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
    'thread_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goalMeta = const VerificationMeta('goal');
  @override
  late final GeneratedColumn<String> goal = GeneratedColumn<String>(
    'goal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _metricsJsonMeta = const VerificationMeta(
    'metricsJson',
  );
  @override
  late final GeneratedColumn<String> metricsJson = GeneratedColumn<String>(
    'metrics_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSyncedMeta = const VerificationMeta(
    'isSynced',
  );
  @override
  late final GeneratedColumn<bool> isSynced = GeneratedColumn<bool>(
    'is_synced',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_synced" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _localeMeta = const VerificationMeta('locale');
  @override
  late final GeneratedColumn<String> locale = GeneratedColumn<String>(
    'locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    partnerId,
    partnerName,
    threadId,
    goal,
    startedAt,
    endedAt,
    durationSeconds,
    metricsJson,
    isSynced,
    locale,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('partner_id')) {
      context.handle(
        _partnerIdMeta,
        partnerId.isAcceptableOrUnknown(data['partner_id']!, _partnerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partnerIdMeta);
    }
    if (data.containsKey('partner_name')) {
      context.handle(
        _partnerNameMeta,
        partnerName.isAcceptableOrUnknown(
          data['partner_name']!,
          _partnerNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_partnerNameMeta);
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    }
    if (data.containsKey('goal')) {
      context.handle(
        _goalMeta,
        goal.isAcceptableOrUnknown(data['goal']!, _goalMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
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
    if (data.containsKey('metrics_json')) {
      context.handle(
        _metricsJsonMeta,
        metricsJson.isAcceptableOrUnknown(
          data['metrics_json']!,
          _metricsJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_synced')) {
      context.handle(
        _isSyncedMeta,
        isSynced.isAcceptableOrUnknown(data['is_synced']!, _isSyncedMeta),
      );
    }
    if (data.containsKey('locale')) {
      context.handle(
        _localeMeta,
        locale.isAcceptableOrUnknown(data['locale']!, _localeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      partnerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}partner_id'],
      )!,
      partnerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}partner_name'],
      )!,
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_id'],
      ),
      goal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      ),
      metricsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metrics_json'],
      ),
      isSynced: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_synced'],
      )!,
      locale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locale'],
      )!,
    );
  }

  @override
  $LocalSessionsTable createAlias(String alias) {
    return $LocalSessionsTable(attachedDatabase, alias);
  }
}

class LocalSessionRow extends DataClass implements Insertable<LocalSessionRow> {
  /// Client-generated, assigned before anything touches the network.
  final String id;

  /// `sessions.id` on the server, once `open_voice_session` has returned one.
  /// Null for a session that has never been online.
  final String? serverId;
  final String partnerId;

  /// Denormalised on purpose. A report opened offline has to name its partner,
  /// and `partners` lives in Postgres — R11.5 says full history works offline,
  /// which a foreign key to a remote table cannot deliver.
  final String partnerName;
  final String? threadId;
  final String? goal;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;

  /// `SpeechMetrics.toJson`, computed on the device (R4.3.1).
  final String? metricsJson;

  /// Whether the closing call reached the server. False after a force-kill and
  /// after any offline session; the next launch retries.
  final bool isSynced;

  /// Which filler lexicon the metrics were computed against, so a recomputation
  /// later cannot silently score English rules against another language.
  final String locale;
  const LocalSessionRow({
    required this.id,
    this.serverId,
    required this.partnerId,
    required this.partnerName,
    this.threadId,
    this.goal,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.metricsJson,
    required this.isSynced,
    required this.locale,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['partner_id'] = Variable<String>(partnerId);
    map['partner_name'] = Variable<String>(partnerName);
    if (!nullToAbsent || threadId != null) {
      map['thread_id'] = Variable<String>(threadId);
    }
    if (!nullToAbsent || goal != null) {
      map['goal'] = Variable<String>(goal);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    if (!nullToAbsent || durationSeconds != null) {
      map['duration_seconds'] = Variable<int>(durationSeconds);
    }
    if (!nullToAbsent || metricsJson != null) {
      map['metrics_json'] = Variable<String>(metricsJson);
    }
    map['is_synced'] = Variable<bool>(isSynced);
    map['locale'] = Variable<String>(locale);
    return map;
  }

  LocalSessionsCompanion toCompanion(bool nullToAbsent) {
    return LocalSessionsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      partnerId: Value(partnerId),
      partnerName: Value(partnerName),
      threadId: threadId == null && nullToAbsent
          ? const Value.absent()
          : Value(threadId),
      goal: goal == null && nullToAbsent ? const Value.absent() : Value(goal),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      durationSeconds: durationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSeconds),
      metricsJson: metricsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(metricsJson),
      isSynced: Value(isSynced),
      locale: Value(locale),
    );
  }

  factory LocalSessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSessionRow(
      id: serializer.fromJson<String>(json['id']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      partnerId: serializer.fromJson<String>(json['partnerId']),
      partnerName: serializer.fromJson<String>(json['partnerName']),
      threadId: serializer.fromJson<String?>(json['threadId']),
      goal: serializer.fromJson<String?>(json['goal']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      durationSeconds: serializer.fromJson<int?>(json['durationSeconds']),
      metricsJson: serializer.fromJson<String?>(json['metricsJson']),
      isSynced: serializer.fromJson<bool>(json['isSynced']),
      locale: serializer.fromJson<String>(json['locale']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'serverId': serializer.toJson<String?>(serverId),
      'partnerId': serializer.toJson<String>(partnerId),
      'partnerName': serializer.toJson<String>(partnerName),
      'threadId': serializer.toJson<String?>(threadId),
      'goal': serializer.toJson<String?>(goal),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'durationSeconds': serializer.toJson<int?>(durationSeconds),
      'metricsJson': serializer.toJson<String?>(metricsJson),
      'isSynced': serializer.toJson<bool>(isSynced),
      'locale': serializer.toJson<String>(locale),
    };
  }

  LocalSessionRow copyWith({
    String? id,
    Value<String?> serverId = const Value.absent(),
    String? partnerId,
    String? partnerName,
    Value<String?> threadId = const Value.absent(),
    Value<String?> goal = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    Value<int?> durationSeconds = const Value.absent(),
    Value<String?> metricsJson = const Value.absent(),
    bool? isSynced,
    String? locale,
  }) => LocalSessionRow(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    partnerId: partnerId ?? this.partnerId,
    partnerName: partnerName ?? this.partnerName,
    threadId: threadId.present ? threadId.value : this.threadId,
    goal: goal.present ? goal.value : this.goal,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    durationSeconds: durationSeconds.present
        ? durationSeconds.value
        : this.durationSeconds,
    metricsJson: metricsJson.present ? metricsJson.value : this.metricsJson,
    isSynced: isSynced ?? this.isSynced,
    locale: locale ?? this.locale,
  );
  LocalSessionRow copyWithCompanion(LocalSessionsCompanion data) {
    return LocalSessionRow(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      partnerId: data.partnerId.present ? data.partnerId.value : this.partnerId,
      partnerName: data.partnerName.present
          ? data.partnerName.value
          : this.partnerName,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      goal: data.goal.present ? data.goal.value : this.goal,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      metricsJson: data.metricsJson.present
          ? data.metricsJson.value
          : this.metricsJson,
      isSynced: data.isSynced.present ? data.isSynced.value : this.isSynced,
      locale: data.locale.present ? data.locale.value : this.locale,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSessionRow(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('partnerId: $partnerId, ')
          ..write('partnerName: $partnerName, ')
          ..write('threadId: $threadId, ')
          ..write('goal: $goal, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('metricsJson: $metricsJson, ')
          ..write('isSynced: $isSynced, ')
          ..write('locale: $locale')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    partnerId,
    partnerName,
    threadId,
    goal,
    startedAt,
    endedAt,
    durationSeconds,
    metricsJson,
    isSynced,
    locale,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSessionRow &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.partnerId == this.partnerId &&
          other.partnerName == this.partnerName &&
          other.threadId == this.threadId &&
          other.goal == this.goal &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationSeconds == this.durationSeconds &&
          other.metricsJson == this.metricsJson &&
          other.isSynced == this.isSynced &&
          other.locale == this.locale);
}

class LocalSessionsCompanion extends UpdateCompanion<LocalSessionRow> {
  final Value<String> id;
  final Value<String?> serverId;
  final Value<String> partnerId;
  final Value<String> partnerName;
  final Value<String?> threadId;
  final Value<String?> goal;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<int?> durationSeconds;
  final Value<String?> metricsJson;
  final Value<bool> isSynced;
  final Value<String> locale;
  final Value<int> rowid;
  const LocalSessionsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.partnerId = const Value.absent(),
    this.partnerName = const Value.absent(),
    this.threadId = const Value.absent(),
    this.goal = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.metricsJson = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.locale = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSessionsCompanion.insert({
    required String id,
    this.serverId = const Value.absent(),
    required String partnerId,
    required String partnerName,
    this.threadId = const Value.absent(),
    this.goal = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.metricsJson = const Value.absent(),
    this.isSynced = const Value.absent(),
    this.locale = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       partnerId = Value(partnerId),
       partnerName = Value(partnerName),
       startedAt = Value(startedAt);
  static Insertable<LocalSessionRow> custom({
    Expression<String>? id,
    Expression<String>? serverId,
    Expression<String>? partnerId,
    Expression<String>? partnerName,
    Expression<String>? threadId,
    Expression<String>? goal,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? durationSeconds,
    Expression<String>? metricsJson,
    Expression<bool>? isSynced,
    Expression<String>? locale,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (partnerId != null) 'partner_id': partnerId,
      if (partnerName != null) 'partner_name': partnerName,
      if (threadId != null) 'thread_id': threadId,
      if (goal != null) 'goal': goal,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (metricsJson != null) 'metrics_json': metricsJson,
      if (isSynced != null) 'is_synced': isSynced,
      if (locale != null) 'locale': locale,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSessionsCompanion copyWith({
    Value<String>? id,
    Value<String?>? serverId,
    Value<String>? partnerId,
    Value<String>? partnerName,
    Value<String?>? threadId,
    Value<String?>? goal,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<int?>? durationSeconds,
    Value<String?>? metricsJson,
    Value<bool>? isSynced,
    Value<String>? locale,
    Value<int>? rowid,
  }) {
    return LocalSessionsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      threadId: threadId ?? this.threadId,
      goal: goal ?? this.goal,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      metricsJson: metricsJson ?? this.metricsJson,
      isSynced: isSynced ?? this.isSynced,
      locale: locale ?? this.locale,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (partnerId.present) {
      map['partner_id'] = Variable<String>(partnerId.value);
    }
    if (partnerName.present) {
      map['partner_name'] = Variable<String>(partnerName.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (goal.present) {
      map['goal'] = Variable<String>(goal.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (metricsJson.present) {
      map['metrics_json'] = Variable<String>(metricsJson.value);
    }
    if (isSynced.present) {
      map['is_synced'] = Variable<bool>(isSynced.value);
    }
    if (locale.present) {
      map['locale'] = Variable<String>(locale.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSessionsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('partnerId: $partnerId, ')
          ..write('partnerName: $partnerName, ')
          ..write('threadId: $threadId, ')
          ..write('goal: $goal, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('metricsJson: $metricsJson, ')
          ..write('isSynced: $isSynced, ')
          ..write('locale: $locale, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalTurnsTable extends LocalTurns
    with TableInfo<$LocalTurnsTable, LocalTurnRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalTurnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<int> rowId = GeneratedColumn<int>(
    'row_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES local_sessions (id)',
    ),
  );
  static const VerificationMeta _speakerMeta = const VerificationMeta(
    'speaker',
  );
  @override
  late final GeneratedColumn<String> speaker = GeneratedColumn<String>(
    'speaker',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _startOffsetMsMeta = const VerificationMeta(
    'startOffsetMs',
  );
  @override
  late final GeneratedColumn<int> startOffsetMs = GeneratedColumn<int>(
    'start_offset_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<double> confidence = GeneratedColumn<double>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    rowId,
    sessionId,
    speaker,
    content,
    startOffsetMs,
    durationMs,
    confidence,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_turns';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalTurnRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('speaker')) {
      context.handle(
        _speakerMeta,
        speaker.isAcceptableOrUnknown(data['speaker']!, _speakerMeta),
      );
    } else if (isInserting) {
      context.missing(_speakerMeta);
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('start_offset_ms')) {
      context.handle(
        _startOffsetMsMeta,
        startOffsetMs.isAcceptableOrUnknown(
          data['start_offset_ms']!,
          _startOffsetMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startOffsetMsMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    } else if (isInserting) {
      context.missing(_durationMsMeta);
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rowId};
  @override
  LocalTurnRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalTurnRow(
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      speaker: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}speaker'],
      )!,
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      startOffsetMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}start_offset_ms'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}confidence'],
      )!,
    );
  }

  @override
  $LocalTurnsTable createAlias(String alias) {
    return $LocalTurnsTable(attachedDatabase, alias);
  }
}

class LocalTurnRow extends DataClass implements Insertable<LocalTurnRow> {
  final int rowId;
  final String sessionId;

  /// 'user' or 'partner', matching `Speaker` in the metrics engine.
  ///
  /// Stored as text rather than an index: an enum's ordinal changes the moment
  /// somebody inserts a value, and this row may be read by a build that is
  /// months older than the one that wrote it.
  final String speaker;
  final String content;

  /// From the start of the session, so `TranscriptTurn` reconstructs exactly.
  final int startOffsetMs;
  final int durationMs;

  /// The recogniser's confidence for a user turn (R4.2.5 lets the user tap a
  /// line to see what was heard; a low number here is why they would).
  final double confidence;
  const LocalTurnRow({
    required this.rowId,
    required this.sessionId,
    required this.speaker,
    required this.content,
    required this.startOffsetMs,
    required this.durationMs,
    required this.confidence,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_id'] = Variable<int>(rowId);
    map['session_id'] = Variable<String>(sessionId);
    map['speaker'] = Variable<String>(speaker);
    map['content'] = Variable<String>(content);
    map['start_offset_ms'] = Variable<int>(startOffsetMs);
    map['duration_ms'] = Variable<int>(durationMs);
    map['confidence'] = Variable<double>(confidence);
    return map;
  }

  LocalTurnsCompanion toCompanion(bool nullToAbsent) {
    return LocalTurnsCompanion(
      rowId: Value(rowId),
      sessionId: Value(sessionId),
      speaker: Value(speaker),
      content: Value(content),
      startOffsetMs: Value(startOffsetMs),
      durationMs: Value(durationMs),
      confidence: Value(confidence),
    );
  }

  factory LocalTurnRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalTurnRow(
      rowId: serializer.fromJson<int>(json['rowId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      speaker: serializer.fromJson<String>(json['speaker']),
      content: serializer.fromJson<String>(json['content']),
      startOffsetMs: serializer.fromJson<int>(json['startOffsetMs']),
      durationMs: serializer.fromJson<int>(json['durationMs']),
      confidence: serializer.fromJson<double>(json['confidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowId': serializer.toJson<int>(rowId),
      'sessionId': serializer.toJson<String>(sessionId),
      'speaker': serializer.toJson<String>(speaker),
      'content': serializer.toJson<String>(content),
      'startOffsetMs': serializer.toJson<int>(startOffsetMs),
      'durationMs': serializer.toJson<int>(durationMs),
      'confidence': serializer.toJson<double>(confidence),
    };
  }

  LocalTurnRow copyWith({
    int? rowId,
    String? sessionId,
    String? speaker,
    String? content,
    int? startOffsetMs,
    int? durationMs,
    double? confidence,
  }) => LocalTurnRow(
    rowId: rowId ?? this.rowId,
    sessionId: sessionId ?? this.sessionId,
    speaker: speaker ?? this.speaker,
    content: content ?? this.content,
    startOffsetMs: startOffsetMs ?? this.startOffsetMs,
    durationMs: durationMs ?? this.durationMs,
    confidence: confidence ?? this.confidence,
  );
  LocalTurnRow copyWithCompanion(LocalTurnsCompanion data) {
    return LocalTurnRow(
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      speaker: data.speaker.present ? data.speaker.value : this.speaker,
      content: data.content.present ? data.content.value : this.content,
      startOffsetMs: data.startOffsetMs.present
          ? data.startOffsetMs.value
          : this.startOffsetMs,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalTurnRow(')
          ..write('rowId: $rowId, ')
          ..write('sessionId: $sessionId, ')
          ..write('speaker: $speaker, ')
          ..write('content: $content, ')
          ..write('startOffsetMs: $startOffsetMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rowId,
    sessionId,
    speaker,
    content,
    startOffsetMs,
    durationMs,
    confidence,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalTurnRow &&
          other.rowId == this.rowId &&
          other.sessionId == this.sessionId &&
          other.speaker == this.speaker &&
          other.content == this.content &&
          other.startOffsetMs == this.startOffsetMs &&
          other.durationMs == this.durationMs &&
          other.confidence == this.confidence);
}

class LocalTurnsCompanion extends UpdateCompanion<LocalTurnRow> {
  final Value<int> rowId;
  final Value<String> sessionId;
  final Value<String> speaker;
  final Value<String> content;
  final Value<int> startOffsetMs;
  final Value<int> durationMs;
  final Value<double> confidence;
  const LocalTurnsCompanion({
    this.rowId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.speaker = const Value.absent(),
    this.content = const Value.absent(),
    this.startOffsetMs = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.confidence = const Value.absent(),
  });
  LocalTurnsCompanion.insert({
    this.rowId = const Value.absent(),
    required String sessionId,
    required String speaker,
    required String content,
    required int startOffsetMs,
    required int durationMs,
    this.confidence = const Value.absent(),
  }) : sessionId = Value(sessionId),
       speaker = Value(speaker),
       content = Value(content),
       startOffsetMs = Value(startOffsetMs),
       durationMs = Value(durationMs);
  static Insertable<LocalTurnRow> custom({
    Expression<int>? rowId,
    Expression<String>? sessionId,
    Expression<String>? speaker,
    Expression<String>? content,
    Expression<int>? startOffsetMs,
    Expression<int>? durationMs,
    Expression<double>? confidence,
  }) {
    return RawValuesInsertable({
      if (rowId != null) 'row_id': rowId,
      if (sessionId != null) 'session_id': sessionId,
      if (speaker != null) 'speaker': speaker,
      if (content != null) 'content': content,
      if (startOffsetMs != null) 'start_offset_ms': startOffsetMs,
      if (durationMs != null) 'duration_ms': durationMs,
      if (confidence != null) 'confidence': confidence,
    });
  }

  LocalTurnsCompanion copyWith({
    Value<int>? rowId,
    Value<String>? sessionId,
    Value<String>? speaker,
    Value<String>? content,
    Value<int>? startOffsetMs,
    Value<int>? durationMs,
    Value<double>? confidence,
  }) {
    return LocalTurnsCompanion(
      rowId: rowId ?? this.rowId,
      sessionId: sessionId ?? this.sessionId,
      speaker: speaker ?? this.speaker,
      content: content ?? this.content,
      startOffsetMs: startOffsetMs ?? this.startOffsetMs,
      durationMs: durationMs ?? this.durationMs,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowId.present) {
      map['row_id'] = Variable<int>(rowId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (speaker.present) {
      map['speaker'] = Variable<String>(speaker.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (startOffsetMs.present) {
      map['start_offset_ms'] = Variable<int>(startOffsetMs.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<double>(confidence.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalTurnsCompanion(')
          ..write('rowId: $rowId, ')
          ..write('sessionId: $sessionId, ')
          ..write('speaker: $speaker, ')
          ..write('content: $content, ')
          ..write('startOffsetMs: $startOffsetMs, ')
          ..write('durationMs: $durationMs, ')
          ..write('confidence: $confidence')
          ..write(')'))
        .toString();
  }
}

abstract class _$SessionDatabase extends GeneratedDatabase {
  _$SessionDatabase(QueryExecutor e) : super(e);
  $SessionDatabaseManager get managers => $SessionDatabaseManager(this);
  late final $LocalSessionsTable localSessions = $LocalSessionsTable(this);
  late final $LocalTurnsTable localTurns = $LocalTurnsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localSessions,
    localTurns,
  ];
}

typedef $$LocalSessionsTableCreateCompanionBuilder =
    LocalSessionsCompanion Function({
      required String id,
      Value<String?> serverId,
      required String partnerId,
      required String partnerName,
      Value<String?> threadId,
      Value<String?> goal,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<int?> durationSeconds,
      Value<String?> metricsJson,
      Value<bool> isSynced,
      Value<String> locale,
      Value<int> rowid,
    });
typedef $$LocalSessionsTableUpdateCompanionBuilder =
    LocalSessionsCompanion Function({
      Value<String> id,
      Value<String?> serverId,
      Value<String> partnerId,
      Value<String> partnerName,
      Value<String?> threadId,
      Value<String?> goal,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<int?> durationSeconds,
      Value<String?> metricsJson,
      Value<bool> isSynced,
      Value<String> locale,
      Value<int> rowid,
    });

final class $$LocalSessionsTableReferences
    extends
        BaseReferences<
          _$SessionDatabase,
          $LocalSessionsTable,
          LocalSessionRow
        > {
  $$LocalSessionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$LocalTurnsTable, List<LocalTurnRow>>
  _localTurnsRefsTable(_$SessionDatabase db) => MultiTypedResultKey.fromTable(
    db.localTurns,
    aliasName: $_aliasNameGenerator(
      db.localSessions.id,
      db.localTurns.sessionId,
    ),
  );

  $$LocalTurnsTableProcessedTableManager get localTurnsRefs {
    final manager = $$LocalTurnsTableTableManager(
      $_db,
      $_db.localTurns,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_localTurnsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$LocalSessionsTableFilterComposer
    extends Composer<_$SessionDatabase, $LocalSessionsTable> {
  $$LocalSessionsTableFilterComposer({
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

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partnerId => $composableBuilder(
    column: $table.partnerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get partnerName => $composableBuilder(
    column: $table.partnerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metricsJson => $composableBuilder(
    column: $table.metricsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> localTurnsRefs(
    Expression<bool> Function($$LocalTurnsTableFilterComposer f) f,
  ) {
    final $$LocalTurnsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localTurns,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTurnsTableFilterComposer(
            $db: $db,
            $table: $db.localTurns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalSessionsTableOrderingComposer
    extends Composer<_$SessionDatabase, $LocalSessionsTable> {
  $$LocalSessionsTableOrderingComposer({
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

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partnerId => $composableBuilder(
    column: $table.partnerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get partnerName => $composableBuilder(
    column: $table.partnerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goal => $composableBuilder(
    column: $table.goal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metricsJson => $composableBuilder(
    column: $table.metricsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSynced => $composableBuilder(
    column: $table.isSynced,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locale => $composableBuilder(
    column: $table.locale,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSessionsTableAnnotationComposer
    extends Composer<_$SessionDatabase, $LocalSessionsTable> {
  $$LocalSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get partnerId =>
      $composableBuilder(column: $table.partnerId, builder: (column) => column);

  GeneratedColumn<String> get partnerName => $composableBuilder(
    column: $table.partnerName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<String> get goal =>
      $composableBuilder(column: $table.goal, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get metricsJson => $composableBuilder(
    column: $table.metricsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isSynced =>
      $composableBuilder(column: $table.isSynced, builder: (column) => column);

  GeneratedColumn<String> get locale =>
      $composableBuilder(column: $table.locale, builder: (column) => column);

  Expression<T> localTurnsRefs<T extends Object>(
    Expression<T> Function($$LocalTurnsTableAnnotationComposer a) f,
  ) {
    final $$LocalTurnsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.localTurns,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalTurnsTableAnnotationComposer(
            $db: $db,
            $table: $db.localTurns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$LocalSessionsTableTableManager
    extends
        RootTableManager<
          _$SessionDatabase,
          $LocalSessionsTable,
          LocalSessionRow,
          $$LocalSessionsTableFilterComposer,
          $$LocalSessionsTableOrderingComposer,
          $$LocalSessionsTableAnnotationComposer,
          $$LocalSessionsTableCreateCompanionBuilder,
          $$LocalSessionsTableUpdateCompanionBuilder,
          (LocalSessionRow, $$LocalSessionsTableReferences),
          LocalSessionRow,
          PrefetchHooks Function({bool localTurnsRefs})
        > {
  $$LocalSessionsTableTableManager(
    _$SessionDatabase db,
    $LocalSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> partnerId = const Value.absent(),
                Value<String> partnerName = const Value.absent(),
                Value<String?> threadId = const Value.absent(),
                Value<String?> goal = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> metricsJson = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSessionsCompanion(
                id: id,
                serverId: serverId,
                partnerId: partnerId,
                partnerName: partnerName,
                threadId: threadId,
                goal: goal,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                metricsJson: metricsJson,
                isSynced: isSynced,
                locale: locale,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> serverId = const Value.absent(),
                required String partnerId,
                required String partnerName,
                Value<String?> threadId = const Value.absent(),
                Value<String?> goal = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int?> durationSeconds = const Value.absent(),
                Value<String?> metricsJson = const Value.absent(),
                Value<bool> isSynced = const Value.absent(),
                Value<String> locale = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSessionsCompanion.insert(
                id: id,
                serverId: serverId,
                partnerId: partnerId,
                partnerName: partnerName,
                threadId: threadId,
                goal: goal,
                startedAt: startedAt,
                endedAt: endedAt,
                durationSeconds: durationSeconds,
                metricsJson: metricsJson,
                isSynced: isSynced,
                locale: locale,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({localTurnsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (localTurnsRefs) db.localTurns],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localTurnsRefs)
                    await $_getPrefetchedData<
                      LocalSessionRow,
                      $LocalSessionsTable,
                      LocalTurnRow
                    >(
                      currentTable: table,
                      referencedTable: $$LocalSessionsTableReferences
                          ._localTurnsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$LocalSessionsTableReferences(
                            db,
                            table,
                            p0,
                          ).localTurnsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$LocalSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$SessionDatabase,
      $LocalSessionsTable,
      LocalSessionRow,
      $$LocalSessionsTableFilterComposer,
      $$LocalSessionsTableOrderingComposer,
      $$LocalSessionsTableAnnotationComposer,
      $$LocalSessionsTableCreateCompanionBuilder,
      $$LocalSessionsTableUpdateCompanionBuilder,
      (LocalSessionRow, $$LocalSessionsTableReferences),
      LocalSessionRow,
      PrefetchHooks Function({bool localTurnsRefs})
    >;
typedef $$LocalTurnsTableCreateCompanionBuilder =
    LocalTurnsCompanion Function({
      Value<int> rowId,
      required String sessionId,
      required String speaker,
      required String content,
      required int startOffsetMs,
      required int durationMs,
      Value<double> confidence,
    });
typedef $$LocalTurnsTableUpdateCompanionBuilder =
    LocalTurnsCompanion Function({
      Value<int> rowId,
      Value<String> sessionId,
      Value<String> speaker,
      Value<String> content,
      Value<int> startOffsetMs,
      Value<int> durationMs,
      Value<double> confidence,
    });

final class $$LocalTurnsTableReferences
    extends BaseReferences<_$SessionDatabase, $LocalTurnsTable, LocalTurnRow> {
  $$LocalTurnsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $LocalSessionsTable _sessionIdTable(_$SessionDatabase db) =>
      db.localSessions.createAlias(
        $_aliasNameGenerator(db.localTurns.sessionId, db.localSessions.id),
      );

  $$LocalSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$LocalSessionsTableTableManager(
      $_db,
      $_db.localSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LocalTurnsTableFilterComposer
    extends Composer<_$SessionDatabase, $LocalTurnsTable> {
  $$LocalTurnsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get speaker => $composableBuilder(
    column: $table.speaker,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startOffsetMs => $composableBuilder(
    column: $table.startOffsetMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  $$LocalSessionsTableFilterComposer get sessionId {
    final $$LocalSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.localSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSessionsTableFilterComposer(
            $db: $db,
            $table: $db.localSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalTurnsTableOrderingComposer
    extends Composer<_$SessionDatabase, $LocalTurnsTable> {
  $$LocalTurnsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get speaker => $composableBuilder(
    column: $table.speaker,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startOffsetMs => $composableBuilder(
    column: $table.startOffsetMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  $$LocalSessionsTableOrderingComposer get sessionId {
    final $$LocalSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.localSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.localSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalTurnsTableAnnotationComposer
    extends Composer<_$SessionDatabase, $LocalTurnsTable> {
  $$LocalTurnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumn<String> get speaker =>
      $composableBuilder(column: $table.speaker, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get startOffsetMs => $composableBuilder(
    column: $table.startOffsetMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<double> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  $$LocalSessionsTableAnnotationComposer get sessionId {
    final $$LocalSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.localSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LocalSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.localSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LocalTurnsTableTableManager
    extends
        RootTableManager<
          _$SessionDatabase,
          $LocalTurnsTable,
          LocalTurnRow,
          $$LocalTurnsTableFilterComposer,
          $$LocalTurnsTableOrderingComposer,
          $$LocalTurnsTableAnnotationComposer,
          $$LocalTurnsTableCreateCompanionBuilder,
          $$LocalTurnsTableUpdateCompanionBuilder,
          (LocalTurnRow, $$LocalTurnsTableReferences),
          LocalTurnRow,
          PrefetchHooks Function({bool sessionId})
        > {
  $$LocalTurnsTableTableManager(_$SessionDatabase db, $LocalTurnsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalTurnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalTurnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalTurnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> speaker = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int> startOffsetMs = const Value.absent(),
                Value<int> durationMs = const Value.absent(),
                Value<double> confidence = const Value.absent(),
              }) => LocalTurnsCompanion(
                rowId: rowId,
                sessionId: sessionId,
                speaker: speaker,
                content: content,
                startOffsetMs: startOffsetMs,
                durationMs: durationMs,
                confidence: confidence,
              ),
          createCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                required String sessionId,
                required String speaker,
                required String content,
                required int startOffsetMs,
                required int durationMs,
                Value<double> confidence = const Value.absent(),
              }) => LocalTurnsCompanion.insert(
                rowId: rowId,
                sessionId: sessionId,
                speaker: speaker,
                content: content,
                startOffsetMs: startOffsetMs,
                durationMs: durationMs,
                confidence: confidence,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LocalTurnsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionId = false}) {
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
                    if (sessionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionId,
                                referencedTable: $$LocalTurnsTableReferences
                                    ._sessionIdTable(db),
                                referencedColumn: $$LocalTurnsTableReferences
                                    ._sessionIdTable(db)
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

typedef $$LocalTurnsTableProcessedTableManager =
    ProcessedTableManager<
      _$SessionDatabase,
      $LocalTurnsTable,
      LocalTurnRow,
      $$LocalTurnsTableFilterComposer,
      $$LocalTurnsTableOrderingComposer,
      $$LocalTurnsTableAnnotationComposer,
      $$LocalTurnsTableCreateCompanionBuilder,
      $$LocalTurnsTableUpdateCompanionBuilder,
      (LocalTurnRow, $$LocalTurnsTableReferences),
      LocalTurnRow,
      PrefetchHooks Function({bool sessionId})
    >;

class $SessionDatabaseManager {
  final _$SessionDatabase _db;
  $SessionDatabaseManager(this._db);
  $$LocalSessionsTableTableManager get localSessions =>
      $$LocalSessionsTableTableManager(_db, _db.localSessions);
  $$LocalTurnsTableTableManager get localTurns =>
      $$LocalTurnsTableTableManager(_db, _db.localTurns);
}
