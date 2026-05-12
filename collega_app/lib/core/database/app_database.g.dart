// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CollegeImportsTable extends CollegeImports
    with TableInfo<$CollegeImportsTable, CollegeImport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollegeImportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  @override
  late final GeneratedColumn<int> refId = GeneratedColumn<int>(
      'ref_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _jobIdMeta = const VerificationMeta('jobId');
  @override
  late final GeneratedColumn<String> jobId = GeneratedColumn<String>(
      'job_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ocrProgressMeta =
      const VerificationMeta('ocrProgress');
  @override
  late final GeneratedColumn<int> ocrProgress = GeneratedColumn<int>(
      'ocr_progress', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalPagesMeta =
      const VerificationMeta('totalPages');
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
      'total_pages', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, refId, jobId, status, ocrProgress, totalPages, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'college_imports';
  @override
  VerificationContext validateIntegrity(Insertable<CollegeImport> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ref_id')) {
      context.handle(
          _refIdMeta, refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta));
    } else if (isInserting) {
      context.missing(_refIdMeta);
    }
    if (data.containsKey('job_id')) {
      context.handle(
          _jobIdMeta, jobId.isAcceptableOrUnknown(data['job_id']!, _jobIdMeta));
    } else if (isInserting) {
      context.missing(_jobIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('ocr_progress')) {
      context.handle(
          _ocrProgressMeta,
          ocrProgress.isAcceptableOrUnknown(
              data['ocr_progress']!, _ocrProgressMeta));
    }
    if (data.containsKey('total_pages')) {
      context.handle(
          _totalPagesMeta,
          totalPages.isAcceptableOrUnknown(
              data['total_pages']!, _totalPagesMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollegeImport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollegeImport(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      refId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ref_id'])!,
      jobId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}job_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      ocrProgress: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ocr_progress'])!,
      totalPages: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_pages']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CollegeImportsTable createAlias(String alias) {
    return $CollegeImportsTable(attachedDatabase, alias);
  }
}

class CollegeImport extends DataClass implements Insertable<CollegeImport> {
  final String id;
  final int refId;
  final String jobId;
  final String status;
  final int ocrProgress;
  final int? totalPages;
  final DateTime updatedAt;
  const CollegeImport(
      {required this.id,
      required this.refId,
      required this.jobId,
      required this.status,
      required this.ocrProgress,
      this.totalPages,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ref_id'] = Variable<int>(refId);
    map['job_id'] = Variable<String>(jobId);
    map['status'] = Variable<String>(status);
    map['ocr_progress'] = Variable<int>(ocrProgress);
    if (!nullToAbsent || totalPages != null) {
      map['total_pages'] = Variable<int>(totalPages);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CollegeImportsCompanion toCompanion(bool nullToAbsent) {
    return CollegeImportsCompanion(
      id: Value(id),
      refId: Value(refId),
      jobId: Value(jobId),
      status: Value(status),
      ocrProgress: Value(ocrProgress),
      totalPages: totalPages == null && nullToAbsent
          ? const Value.absent()
          : Value(totalPages),
      updatedAt: Value(updatedAt),
    );
  }

  factory CollegeImport.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollegeImport(
      id: serializer.fromJson<String>(json['id']),
      refId: serializer.fromJson<int>(json['refId']),
      jobId: serializer.fromJson<String>(json['jobId']),
      status: serializer.fromJson<String>(json['status']),
      ocrProgress: serializer.fromJson<int>(json['ocrProgress']),
      totalPages: serializer.fromJson<int?>(json['totalPages']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'refId': serializer.toJson<int>(refId),
      'jobId': serializer.toJson<String>(jobId),
      'status': serializer.toJson<String>(status),
      'ocrProgress': serializer.toJson<int>(ocrProgress),
      'totalPages': serializer.toJson<int?>(totalPages),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CollegeImport copyWith(
          {String? id,
          int? refId,
          String? jobId,
          String? status,
          int? ocrProgress,
          Value<int?> totalPages = const Value.absent(),
          DateTime? updatedAt}) =>
      CollegeImport(
        id: id ?? this.id,
        refId: refId ?? this.refId,
        jobId: jobId ?? this.jobId,
        status: status ?? this.status,
        ocrProgress: ocrProgress ?? this.ocrProgress,
        totalPages: totalPages.present ? totalPages.value : this.totalPages,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  CollegeImport copyWithCompanion(CollegeImportsCompanion data) {
    return CollegeImport(
      id: data.id.present ? data.id.value : this.id,
      refId: data.refId.present ? data.refId.value : this.refId,
      jobId: data.jobId.present ? data.jobId.value : this.jobId,
      status: data.status.present ? data.status.value : this.status,
      ocrProgress:
          data.ocrProgress.present ? data.ocrProgress.value : this.ocrProgress,
      totalPages:
          data.totalPages.present ? data.totalPages.value : this.totalPages,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollegeImport(')
          ..write('id: $id, ')
          ..write('refId: $refId, ')
          ..write('jobId: $jobId, ')
          ..write('status: $status, ')
          ..write('ocrProgress: $ocrProgress, ')
          ..write('totalPages: $totalPages, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, refId, jobId, status, ocrProgress, totalPages, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollegeImport &&
          other.id == this.id &&
          other.refId == this.refId &&
          other.jobId == this.jobId &&
          other.status == this.status &&
          other.ocrProgress == this.ocrProgress &&
          other.totalPages == this.totalPages &&
          other.updatedAt == this.updatedAt);
}

class CollegeImportsCompanion extends UpdateCompanion<CollegeImport> {
  final Value<String> id;
  final Value<int> refId;
  final Value<String> jobId;
  final Value<String> status;
  final Value<int> ocrProgress;
  final Value<int?> totalPages;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CollegeImportsCompanion({
    this.id = const Value.absent(),
    this.refId = const Value.absent(),
    this.jobId = const Value.absent(),
    this.status = const Value.absent(),
    this.ocrProgress = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CollegeImportsCompanion.insert({
    required String id,
    required int refId,
    required String jobId,
    required String status,
    this.ocrProgress = const Value.absent(),
    this.totalPages = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        refId = Value(refId),
        jobId = Value(jobId),
        status = Value(status),
        updatedAt = Value(updatedAt);
  static Insertable<CollegeImport> custom({
    Expression<String>? id,
    Expression<int>? refId,
    Expression<String>? jobId,
    Expression<String>? status,
    Expression<int>? ocrProgress,
    Expression<int>? totalPages,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (refId != null) 'ref_id': refId,
      if (jobId != null) 'job_id': jobId,
      if (status != null) 'status': status,
      if (ocrProgress != null) 'ocr_progress': ocrProgress,
      if (totalPages != null) 'total_pages': totalPages,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CollegeImportsCompanion copyWith(
      {Value<String>? id,
      Value<int>? refId,
      Value<String>? jobId,
      Value<String>? status,
      Value<int>? ocrProgress,
      Value<int?>? totalPages,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return CollegeImportsCompanion(
      id: id ?? this.id,
      refId: refId ?? this.refId,
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      ocrProgress: ocrProgress ?? this.ocrProgress,
      totalPages: totalPages ?? this.totalPages,
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
    if (refId.present) {
      map['ref_id'] = Variable<int>(refId.value);
    }
    if (jobId.present) {
      map['job_id'] = Variable<String>(jobId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (ocrProgress.present) {
      map['ocr_progress'] = Variable<int>(ocrProgress.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollegeImportsCompanion(')
          ..write('id: $id, ')
          ..write('refId: $refId, ')
          ..write('jobId: $jobId, ')
          ..write('status: $status, ')
          ..write('ocrProgress: $ocrProgress, ')
          ..write('totalPages: $totalPages, ')
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
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _collegeIdMeta =
      const VerificationMeta('collegeId');
  @override
  late final GeneratedColumn<String> collegeId = GeneratedColumn<String>(
      'college_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemNumberMeta =
      const VerificationMeta('itemNumber');
  @override
  late final GeneratedColumn<int> itemNumber = GeneratedColumn<int>(
      'item_number', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _rangMeta = const VerificationMeta('rang');
  @override
  late final GeneratedColumn<String> rang = GeneratedColumn<String>(
      'rang', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _chapterTitleMeta =
      const VerificationMeta('chapterTitle');
  @override
  late final GeneratedColumn<String> chapterTitle = GeneratedColumn<String>(
      'chapter_title', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ocrConfidenceScoreMeta =
      const VerificationMeta('ocrConfidenceScore');
  @override
  late final GeneratedColumn<double> ocrConfidenceScore =
      GeneratedColumn<double>('ocr_confidence_score', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0.0));
  static const VerificationMeta _lowConfidenceMeta =
      const VerificationMeta('lowConfidence');
  @override
  late final GeneratedColumn<bool> lowConfidence = GeneratedColumn<bool>(
      'low_confidence', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("low_confidence" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        collegeId,
        itemNumber,
        rang,
        chapterTitle,
        ocrConfidenceScore,
        lowConfidence
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'items';
  @override
  VerificationContext validateIntegrity(Insertable<Item> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('college_id')) {
      context.handle(_collegeIdMeta,
          collegeId.isAcceptableOrUnknown(data['college_id']!, _collegeIdMeta));
    } else if (isInserting) {
      context.missing(_collegeIdMeta);
    }
    if (data.containsKey('item_number')) {
      context.handle(
          _itemNumberMeta,
          itemNumber.isAcceptableOrUnknown(
              data['item_number']!, _itemNumberMeta));
    } else if (isInserting) {
      context.missing(_itemNumberMeta);
    }
    if (data.containsKey('rang')) {
      context.handle(
          _rangMeta, rang.isAcceptableOrUnknown(data['rang']!, _rangMeta));
    } else if (isInserting) {
      context.missing(_rangMeta);
    }
    if (data.containsKey('chapter_title')) {
      context.handle(
          _chapterTitleMeta,
          chapterTitle.isAcceptableOrUnknown(
              data['chapter_title']!, _chapterTitleMeta));
    }
    if (data.containsKey('ocr_confidence_score')) {
      context.handle(
          _ocrConfidenceScoreMeta,
          ocrConfidenceScore.isAcceptableOrUnknown(
              data['ocr_confidence_score']!, _ocrConfidenceScoreMeta));
    }
    if (data.containsKey('low_confidence')) {
      context.handle(
          _lowConfidenceMeta,
          lowConfidence.isAcceptableOrUnknown(
              data['low_confidence']!, _lowConfidenceMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Item map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Item(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      collegeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}college_id'])!,
      itemNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}item_number'])!,
      rang: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rang'])!,
      chapterTitle: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}chapter_title']),
      ocrConfidenceScore: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}ocr_confidence_score'])!,
      lowConfidence: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}low_confidence'])!,
    );
  }

  @override
  $ItemsTable createAlias(String alias) {
    return $ItemsTable(attachedDatabase, alias);
  }
}

class Item extends DataClass implements Insertable<Item> {
  final String id;
  final String collegeId;
  final int itemNumber;
  final String rang;
  final String? chapterTitle;
  final double ocrConfidenceScore;
  final bool lowConfidence;
  const Item(
      {required this.id,
      required this.collegeId,
      required this.itemNumber,
      required this.rang,
      this.chapterTitle,
      required this.ocrConfidenceScore,
      required this.lowConfidence});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['college_id'] = Variable<String>(collegeId);
    map['item_number'] = Variable<int>(itemNumber);
    map['rang'] = Variable<String>(rang);
    if (!nullToAbsent || chapterTitle != null) {
      map['chapter_title'] = Variable<String>(chapterTitle);
    }
    map['ocr_confidence_score'] = Variable<double>(ocrConfidenceScore);
    map['low_confidence'] = Variable<bool>(lowConfidence);
    return map;
  }

  ItemsCompanion toCompanion(bool nullToAbsent) {
    return ItemsCompanion(
      id: Value(id),
      collegeId: Value(collegeId),
      itemNumber: Value(itemNumber),
      rang: Value(rang),
      chapterTitle: chapterTitle == null && nullToAbsent
          ? const Value.absent()
          : Value(chapterTitle),
      ocrConfidenceScore: Value(ocrConfidenceScore),
      lowConfidence: Value(lowConfidence),
    );
  }

  factory Item.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Item(
      id: serializer.fromJson<String>(json['id']),
      collegeId: serializer.fromJson<String>(json['collegeId']),
      itemNumber: serializer.fromJson<int>(json['itemNumber']),
      rang: serializer.fromJson<String>(json['rang']),
      chapterTitle: serializer.fromJson<String?>(json['chapterTitle']),
      ocrConfidenceScore:
          serializer.fromJson<double>(json['ocrConfidenceScore']),
      lowConfidence: serializer.fromJson<bool>(json['lowConfidence']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'collegeId': serializer.toJson<String>(collegeId),
      'itemNumber': serializer.toJson<int>(itemNumber),
      'rang': serializer.toJson<String>(rang),
      'chapterTitle': serializer.toJson<String?>(chapterTitle),
      'ocrConfidenceScore': serializer.toJson<double>(ocrConfidenceScore),
      'lowConfidence': serializer.toJson<bool>(lowConfidence),
    };
  }

  Item copyWith(
          {String? id,
          String? collegeId,
          int? itemNumber,
          String? rang,
          Value<String?> chapterTitle = const Value.absent(),
          double? ocrConfidenceScore,
          bool? lowConfidence}) =>
      Item(
        id: id ?? this.id,
        collegeId: collegeId ?? this.collegeId,
        itemNumber: itemNumber ?? this.itemNumber,
        rang: rang ?? this.rang,
        chapterTitle:
            chapterTitle.present ? chapterTitle.value : this.chapterTitle,
        ocrConfidenceScore: ocrConfidenceScore ?? this.ocrConfidenceScore,
        lowConfidence: lowConfidence ?? this.lowConfidence,
      );
  Item copyWithCompanion(ItemsCompanion data) {
    return Item(
      id: data.id.present ? data.id.value : this.id,
      collegeId: data.collegeId.present ? data.collegeId.value : this.collegeId,
      itemNumber:
          data.itemNumber.present ? data.itemNumber.value : this.itemNumber,
      rang: data.rang.present ? data.rang.value : this.rang,
      chapterTitle: data.chapterTitle.present
          ? data.chapterTitle.value
          : this.chapterTitle,
      ocrConfidenceScore: data.ocrConfidenceScore.present
          ? data.ocrConfidenceScore.value
          : this.ocrConfidenceScore,
      lowConfidence: data.lowConfidence.present
          ? data.lowConfidence.value
          : this.lowConfidence,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Item(')
          ..write('id: $id, ')
          ..write('collegeId: $collegeId, ')
          ..write('itemNumber: $itemNumber, ')
          ..write('rang: $rang, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('ocrConfidenceScore: $ocrConfidenceScore, ')
          ..write('lowConfidence: $lowConfidence')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, collegeId, itemNumber, rang, chapterTitle,
      ocrConfidenceScore, lowConfidence);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Item &&
          other.id == this.id &&
          other.collegeId == this.collegeId &&
          other.itemNumber == this.itemNumber &&
          other.rang == this.rang &&
          other.chapterTitle == this.chapterTitle &&
          other.ocrConfidenceScore == this.ocrConfidenceScore &&
          other.lowConfidence == this.lowConfidence);
}

class ItemsCompanion extends UpdateCompanion<Item> {
  final Value<String> id;
  final Value<String> collegeId;
  final Value<int> itemNumber;
  final Value<String> rang;
  final Value<String?> chapterTitle;
  final Value<double> ocrConfidenceScore;
  final Value<bool> lowConfidence;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.collegeId = const Value.absent(),
    this.itemNumber = const Value.absent(),
    this.rang = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.ocrConfidenceScore = const Value.absent(),
    this.lowConfidence = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ItemsCompanion.insert({
    required String id,
    required String collegeId,
    required int itemNumber,
    required String rang,
    this.chapterTitle = const Value.absent(),
    this.ocrConfidenceScore = const Value.absent(),
    this.lowConfidence = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        collegeId = Value(collegeId),
        itemNumber = Value(itemNumber),
        rang = Value(rang);
  static Insertable<Item> custom({
    Expression<String>? id,
    Expression<String>? collegeId,
    Expression<int>? itemNumber,
    Expression<String>? rang,
    Expression<String>? chapterTitle,
    Expression<double>? ocrConfidenceScore,
    Expression<bool>? lowConfidence,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collegeId != null) 'college_id': collegeId,
      if (itemNumber != null) 'item_number': itemNumber,
      if (rang != null) 'rang': rang,
      if (chapterTitle != null) 'chapter_title': chapterTitle,
      if (ocrConfidenceScore != null)
        'ocr_confidence_score': ocrConfidenceScore,
      if (lowConfidence != null) 'low_confidence': lowConfidence,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? collegeId,
      Value<int>? itemNumber,
      Value<String>? rang,
      Value<String?>? chapterTitle,
      Value<double>? ocrConfidenceScore,
      Value<bool>? lowConfidence,
      Value<int>? rowid}) {
    return ItemsCompanion(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      itemNumber: itemNumber ?? this.itemNumber,
      rang: rang ?? this.rang,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      ocrConfidenceScore: ocrConfidenceScore ?? this.ocrConfidenceScore,
      lowConfidence: lowConfidence ?? this.lowConfidence,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (collegeId.present) {
      map['college_id'] = Variable<String>(collegeId.value);
    }
    if (itemNumber.present) {
      map['item_number'] = Variable<int>(itemNumber.value);
    }
    if (rang.present) {
      map['rang'] = Variable<String>(rang.value);
    }
    if (chapterTitle.present) {
      map['chapter_title'] = Variable<String>(chapterTitle.value);
    }
    if (ocrConfidenceScore.present) {
      map['ocr_confidence_score'] = Variable<double>(ocrConfidenceScore.value);
    }
    if (lowConfidence.present) {
      map['low_confidence'] = Variable<bool>(lowConfidence.value);
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
          ..write('collegeId: $collegeId, ')
          ..write('itemNumber: $itemNumber, ')
          ..write('rang: $rang, ')
          ..write('chapterTitle: $chapterTitle, ')
          ..write('ocrConfidenceScore: $ocrConfidenceScore, ')
          ..write('lowConfidence: $lowConfidence, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FlashCardsTable extends FlashCards
    with TableInfo<$FlashCardsTable, FlashCard> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FlashCardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
      'item_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _collegeIdMeta =
      const VerificationMeta('collegeId');
  @override
  late final GeneratedColumn<String> collegeId = GeneratedColumn<String>(
      'college_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cardTypeMeta =
      const VerificationMeta('cardType');
  @override
  late final GeneratedColumn<String> cardType = GeneratedColumn<String>(
      'card_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rangMeta = const VerificationMeta('rang');
  @override
  late final GeneratedColumn<String> rang = GeneratedColumn<String>(
      'rang', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rectoMeta = const VerificationMeta('recto');
  @override
  late final GeneratedColumn<String> recto = GeneratedColumn<String>(
      'recto', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versoMeta = const VerificationMeta('verso');
  @override
  late final GeneratedColumn<String> verso = GeneratedColumn<String>(
      'verso', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ocrConfidenceScoreMeta =
      const VerificationMeta('ocrConfidenceScore');
  @override
  late final GeneratedColumn<double> ocrConfidenceScore =
      GeneratedColumn<double>('ocr_confidence_score', aliasedName, false,
          type: DriftSqlType.double,
          requiredDuringInsert: false,
          defaultValue: const Constant(0.0));
  static const VerificationMeta _lowConfidenceMeta =
      const VerificationMeta('lowConfidence');
  @override
  late final GeneratedColumn<bool> lowConfidence = GeneratedColumn<bool>(
      'low_confidence', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("low_confidence" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _userFeedbackMeta =
      const VerificationMeta('userFeedback');
  @override
  late final GeneratedColumn<String> userFeedback = GeneratedColumn<String>(
      'user_feedback', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        itemId,
        collegeId,
        cardType,
        rang,
        recto,
        verso,
        ocrConfidenceScore,
        lowConfidence,
        userFeedback
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'flash_cards';
  @override
  VerificationContext validateIntegrity(Insertable<FlashCard> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta,
          itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('college_id')) {
      context.handle(_collegeIdMeta,
          collegeId.isAcceptableOrUnknown(data['college_id']!, _collegeIdMeta));
    } else if (isInserting) {
      context.missing(_collegeIdMeta);
    }
    if (data.containsKey('card_type')) {
      context.handle(_cardTypeMeta,
          cardType.isAcceptableOrUnknown(data['card_type']!, _cardTypeMeta));
    } else if (isInserting) {
      context.missing(_cardTypeMeta);
    }
    if (data.containsKey('rang')) {
      context.handle(
          _rangMeta, rang.isAcceptableOrUnknown(data['rang']!, _rangMeta));
    } else if (isInserting) {
      context.missing(_rangMeta);
    }
    if (data.containsKey('recto')) {
      context.handle(
          _rectoMeta, recto.isAcceptableOrUnknown(data['recto']!, _rectoMeta));
    } else if (isInserting) {
      context.missing(_rectoMeta);
    }
    if (data.containsKey('verso')) {
      context.handle(
          _versoMeta, verso.isAcceptableOrUnknown(data['verso']!, _versoMeta));
    } else if (isInserting) {
      context.missing(_versoMeta);
    }
    if (data.containsKey('ocr_confidence_score')) {
      context.handle(
          _ocrConfidenceScoreMeta,
          ocrConfidenceScore.isAcceptableOrUnknown(
              data['ocr_confidence_score']!, _ocrConfidenceScoreMeta));
    }
    if (data.containsKey('low_confidence')) {
      context.handle(
          _lowConfidenceMeta,
          lowConfidence.isAcceptableOrUnknown(
              data['low_confidence']!, _lowConfidenceMeta));
    }
    if (data.containsKey('user_feedback')) {
      context.handle(
          _userFeedbackMeta,
          userFeedback.isAcceptableOrUnknown(
              data['user_feedback']!, _userFeedbackMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FlashCard map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FlashCard(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      itemId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      collegeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}college_id'])!,
      cardType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_type'])!,
      rang: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rang'])!,
      recto: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recto'])!,
      verso: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}verso'])!,
      ocrConfidenceScore: attachedDatabase.typeMapping.read(
          DriftSqlType.double, data['${effectivePrefix}ocr_confidence_score'])!,
      lowConfidence: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}low_confidence'])!,
      userFeedback: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_feedback']),
    );
  }

  @override
  $FlashCardsTable createAlias(String alias) {
    return $FlashCardsTable(attachedDatabase, alias);
  }
}

class FlashCard extends DataClass implements Insertable<FlashCard> {
  final String id;
  final String itemId;
  final String collegeId;
  final String cardType;
  final String rang;
  final String recto;
  final String verso;
  final double ocrConfidenceScore;
  final bool lowConfidence;
  final String? userFeedback;
  const FlashCard(
      {required this.id,
      required this.itemId,
      required this.collegeId,
      required this.cardType,
      required this.rang,
      required this.recto,
      required this.verso,
      required this.ocrConfidenceScore,
      required this.lowConfidence,
      this.userFeedback});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    map['college_id'] = Variable<String>(collegeId);
    map['card_type'] = Variable<String>(cardType);
    map['rang'] = Variable<String>(rang);
    map['recto'] = Variable<String>(recto);
    map['verso'] = Variable<String>(verso);
    map['ocr_confidence_score'] = Variable<double>(ocrConfidenceScore);
    map['low_confidence'] = Variable<bool>(lowConfidence);
    if (!nullToAbsent || userFeedback != null) {
      map['user_feedback'] = Variable<String>(userFeedback);
    }
    return map;
  }

  FlashCardsCompanion toCompanion(bool nullToAbsent) {
    return FlashCardsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      collegeId: Value(collegeId),
      cardType: Value(cardType),
      rang: Value(rang),
      recto: Value(recto),
      verso: Value(verso),
      ocrConfidenceScore: Value(ocrConfidenceScore),
      lowConfidence: Value(lowConfidence),
      userFeedback: userFeedback == null && nullToAbsent
          ? const Value.absent()
          : Value(userFeedback),
    );
  }

  factory FlashCard.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FlashCard(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      collegeId: serializer.fromJson<String>(json['collegeId']),
      cardType: serializer.fromJson<String>(json['cardType']),
      rang: serializer.fromJson<String>(json['rang']),
      recto: serializer.fromJson<String>(json['recto']),
      verso: serializer.fromJson<String>(json['verso']),
      ocrConfidenceScore:
          serializer.fromJson<double>(json['ocrConfidenceScore']),
      lowConfidence: serializer.fromJson<bool>(json['lowConfidence']),
      userFeedback: serializer.fromJson<String?>(json['userFeedback']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'collegeId': serializer.toJson<String>(collegeId),
      'cardType': serializer.toJson<String>(cardType),
      'rang': serializer.toJson<String>(rang),
      'recto': serializer.toJson<String>(recto),
      'verso': serializer.toJson<String>(verso),
      'ocrConfidenceScore': serializer.toJson<double>(ocrConfidenceScore),
      'lowConfidence': serializer.toJson<bool>(lowConfidence),
      'userFeedback': serializer.toJson<String?>(userFeedback),
    };
  }

  FlashCard copyWith(
          {String? id,
          String? itemId,
          String? collegeId,
          String? cardType,
          String? rang,
          String? recto,
          String? verso,
          double? ocrConfidenceScore,
          bool? lowConfidence,
          Value<String?> userFeedback = const Value.absent()}) =>
      FlashCard(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        collegeId: collegeId ?? this.collegeId,
        cardType: cardType ?? this.cardType,
        rang: rang ?? this.rang,
        recto: recto ?? this.recto,
        verso: verso ?? this.verso,
        ocrConfidenceScore: ocrConfidenceScore ?? this.ocrConfidenceScore,
        lowConfidence: lowConfidence ?? this.lowConfidence,
        userFeedback:
            userFeedback.present ? userFeedback.value : this.userFeedback,
      );
  FlashCard copyWithCompanion(FlashCardsCompanion data) {
    return FlashCard(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      collegeId: data.collegeId.present ? data.collegeId.value : this.collegeId,
      cardType: data.cardType.present ? data.cardType.value : this.cardType,
      rang: data.rang.present ? data.rang.value : this.rang,
      recto: data.recto.present ? data.recto.value : this.recto,
      verso: data.verso.present ? data.verso.value : this.verso,
      ocrConfidenceScore: data.ocrConfidenceScore.present
          ? data.ocrConfidenceScore.value
          : this.ocrConfidenceScore,
      lowConfidence: data.lowConfidence.present
          ? data.lowConfidence.value
          : this.lowConfidence,
      userFeedback: data.userFeedback.present
          ? data.userFeedback.value
          : this.userFeedback,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FlashCard(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('collegeId: $collegeId, ')
          ..write('cardType: $cardType, ')
          ..write('rang: $rang, ')
          ..write('recto: $recto, ')
          ..write('verso: $verso, ')
          ..write('ocrConfidenceScore: $ocrConfidenceScore, ')
          ..write('lowConfidence: $lowConfidence, ')
          ..write('userFeedback: $userFeedback')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, itemId, collegeId, cardType, rang, recto,
      verso, ocrConfidenceScore, lowConfidence, userFeedback);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FlashCard &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.collegeId == this.collegeId &&
          other.cardType == this.cardType &&
          other.rang == this.rang &&
          other.recto == this.recto &&
          other.verso == this.verso &&
          other.ocrConfidenceScore == this.ocrConfidenceScore &&
          other.lowConfidence == this.lowConfidence &&
          other.userFeedback == this.userFeedback);
}

class FlashCardsCompanion extends UpdateCompanion<FlashCard> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String> collegeId;
  final Value<String> cardType;
  final Value<String> rang;
  final Value<String> recto;
  final Value<String> verso;
  final Value<double> ocrConfidenceScore;
  final Value<bool> lowConfidence;
  final Value<String?> userFeedback;
  final Value<int> rowid;
  const FlashCardsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.collegeId = const Value.absent(),
    this.cardType = const Value.absent(),
    this.rang = const Value.absent(),
    this.recto = const Value.absent(),
    this.verso = const Value.absent(),
    this.ocrConfidenceScore = const Value.absent(),
    this.lowConfidence = const Value.absent(),
    this.userFeedback = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FlashCardsCompanion.insert({
    required String id,
    required String itemId,
    required String collegeId,
    required String cardType,
    required String rang,
    required String recto,
    required String verso,
    this.ocrConfidenceScore = const Value.absent(),
    this.lowConfidence = const Value.absent(),
    this.userFeedback = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        itemId = Value(itemId),
        collegeId = Value(collegeId),
        cardType = Value(cardType),
        rang = Value(rang),
        recto = Value(recto),
        verso = Value(verso);
  static Insertable<FlashCard> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? collegeId,
    Expression<String>? cardType,
    Expression<String>? rang,
    Expression<String>? recto,
    Expression<String>? verso,
    Expression<double>? ocrConfidenceScore,
    Expression<bool>? lowConfidence,
    Expression<String>? userFeedback,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (collegeId != null) 'college_id': collegeId,
      if (cardType != null) 'card_type': cardType,
      if (rang != null) 'rang': rang,
      if (recto != null) 'recto': recto,
      if (verso != null) 'verso': verso,
      if (ocrConfidenceScore != null)
        'ocr_confidence_score': ocrConfidenceScore,
      if (lowConfidence != null) 'low_confidence': lowConfidence,
      if (userFeedback != null) 'user_feedback': userFeedback,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FlashCardsCompanion copyWith(
      {Value<String>? id,
      Value<String>? itemId,
      Value<String>? collegeId,
      Value<String>? cardType,
      Value<String>? rang,
      Value<String>? recto,
      Value<String>? verso,
      Value<double>? ocrConfidenceScore,
      Value<bool>? lowConfidence,
      Value<String?>? userFeedback,
      Value<int>? rowid}) {
    return FlashCardsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      collegeId: collegeId ?? this.collegeId,
      cardType: cardType ?? this.cardType,
      rang: rang ?? this.rang,
      recto: recto ?? this.recto,
      verso: verso ?? this.verso,
      ocrConfidenceScore: ocrConfidenceScore ?? this.ocrConfidenceScore,
      lowConfidence: lowConfidence ?? this.lowConfidence,
      userFeedback: userFeedback ?? this.userFeedback,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (collegeId.present) {
      map['college_id'] = Variable<String>(collegeId.value);
    }
    if (cardType.present) {
      map['card_type'] = Variable<String>(cardType.value);
    }
    if (rang.present) {
      map['rang'] = Variable<String>(rang.value);
    }
    if (recto.present) {
      map['recto'] = Variable<String>(recto.value);
    }
    if (verso.present) {
      map['verso'] = Variable<String>(verso.value);
    }
    if (ocrConfidenceScore.present) {
      map['ocr_confidence_score'] = Variable<double>(ocrConfidenceScore.value);
    }
    if (lowConfidence.present) {
      map['low_confidence'] = Variable<bool>(lowConfidence.value);
    }
    if (userFeedback.present) {
      map['user_feedback'] = Variable<String>(userFeedback.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FlashCardsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('collegeId: $collegeId, ')
          ..write('cardType: $cardType, ')
          ..write('rang: $rang, ')
          ..write('recto: $recto, ')
          ..write('verso: $verso, ')
          ..write('ocrConfidenceScore: $ocrConfidenceScore, ')
          ..write('lowConfidence: $lowConfidence, ')
          ..write('userFeedback: $userFeedback, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CollegeImportsTable collegeImports = $CollegeImportsTable(this);
  late final $ItemsTable items = $ItemsTable(this);
  late final $FlashCardsTable flashCards = $FlashCardsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [collegeImports, items, flashCards];
}

typedef $$CollegeImportsTableCreateCompanionBuilder = CollegeImportsCompanion
    Function({
  required String id,
  required int refId,
  required String jobId,
  required String status,
  Value<int> ocrProgress,
  Value<int?> totalPages,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$CollegeImportsTableUpdateCompanionBuilder = CollegeImportsCompanion
    Function({
  Value<String> id,
  Value<int> refId,
  Value<String> jobId,
  Value<String> status,
  Value<int> ocrProgress,
  Value<int?> totalPages,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$CollegeImportsTableFilterComposer
    extends Composer<_$AppDatabase, $CollegeImportsTable> {
  $$CollegeImportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get refId => $composableBuilder(
      column: $table.refId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jobId => $composableBuilder(
      column: $table.jobId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ocrProgress => $composableBuilder(
      column: $table.ocrProgress, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CollegeImportsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollegeImportsTable> {
  $$CollegeImportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get refId => $composableBuilder(
      column: $table.refId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jobId => $composableBuilder(
      column: $table.jobId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ocrProgress => $composableBuilder(
      column: $table.ocrProgress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CollegeImportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollegeImportsTable> {
  $$CollegeImportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get refId =>
      $composableBuilder(column: $table.refId, builder: (column) => column);

  GeneratedColumn<String> get jobId =>
      $composableBuilder(column: $table.jobId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get ocrProgress => $composableBuilder(
      column: $table.ocrProgress, builder: (column) => column);

  GeneratedColumn<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CollegeImportsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CollegeImportsTable,
    CollegeImport,
    $$CollegeImportsTableFilterComposer,
    $$CollegeImportsTableOrderingComposer,
    $$CollegeImportsTableAnnotationComposer,
    $$CollegeImportsTableCreateCompanionBuilder,
    $$CollegeImportsTableUpdateCompanionBuilder,
    (
      CollegeImport,
      BaseReferences<_$AppDatabase, $CollegeImportsTable, CollegeImport>
    ),
    CollegeImport,
    PrefetchHooks Function()> {
  $$CollegeImportsTableTableManager(
      _$AppDatabase db, $CollegeImportsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollegeImportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollegeImportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollegeImportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<int> refId = const Value.absent(),
            Value<String> jobId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> ocrProgress = const Value.absent(),
            Value<int?> totalPages = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CollegeImportsCompanion(
            id: id,
            refId: refId,
            jobId: jobId,
            status: status,
            ocrProgress: ocrProgress,
            totalPages: totalPages,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required int refId,
            required String jobId,
            required String status,
            Value<int> ocrProgress = const Value.absent(),
            Value<int?> totalPages = const Value.absent(),
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              CollegeImportsCompanion.insert(
            id: id,
            refId: refId,
            jobId: jobId,
            status: status,
            ocrProgress: ocrProgress,
            totalPages: totalPages,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CollegeImportsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CollegeImportsTable,
    CollegeImport,
    $$CollegeImportsTableFilterComposer,
    $$CollegeImportsTableOrderingComposer,
    $$CollegeImportsTableAnnotationComposer,
    $$CollegeImportsTableCreateCompanionBuilder,
    $$CollegeImportsTableUpdateCompanionBuilder,
    (
      CollegeImport,
      BaseReferences<_$AppDatabase, $CollegeImportsTable, CollegeImport>
    ),
    CollegeImport,
    PrefetchHooks Function()>;
typedef $$ItemsTableCreateCompanionBuilder = ItemsCompanion Function({
  required String id,
  required String collegeId,
  required int itemNumber,
  required String rang,
  Value<String?> chapterTitle,
  Value<double> ocrConfidenceScore,
  Value<bool> lowConfidence,
  Value<int> rowid,
});
typedef $$ItemsTableUpdateCompanionBuilder = ItemsCompanion Function({
  Value<String> id,
  Value<String> collegeId,
  Value<int> itemNumber,
  Value<String> rang,
  Value<String?> chapterTitle,
  Value<double> ocrConfidenceScore,
  Value<bool> lowConfidence,
  Value<int> rowid,
});

class $$ItemsTableFilterComposer extends Composer<_$AppDatabase, $ItemsTable> {
  $$ItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collegeId => $composableBuilder(
      column: $table.collegeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get itemNumber => $composableBuilder(
      column: $table.itemNumber, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rang => $composableBuilder(
      column: $table.rang, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get chapterTitle => $composableBuilder(
      column: $table.chapterTitle, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get ocrConfidenceScore => $composableBuilder(
      column: $table.ocrConfidenceScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get lowConfidence => $composableBuilder(
      column: $table.lowConfidence, builder: (column) => ColumnFilters(column));
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
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collegeId => $composableBuilder(
      column: $table.collegeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get itemNumber => $composableBuilder(
      column: $table.itemNumber, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rang => $composableBuilder(
      column: $table.rang, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get chapterTitle => $composableBuilder(
      column: $table.chapterTitle,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get ocrConfidenceScore => $composableBuilder(
      column: $table.ocrConfidenceScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get lowConfidence => $composableBuilder(
      column: $table.lowConfidence,
      builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get collegeId =>
      $composableBuilder(column: $table.collegeId, builder: (column) => column);

  GeneratedColumn<int> get itemNumber => $composableBuilder(
      column: $table.itemNumber, builder: (column) => column);

  GeneratedColumn<String> get rang =>
      $composableBuilder(column: $table.rang, builder: (column) => column);

  GeneratedColumn<String> get chapterTitle => $composableBuilder(
      column: $table.chapterTitle, builder: (column) => column);

  GeneratedColumn<double> get ocrConfidenceScore => $composableBuilder(
      column: $table.ocrConfidenceScore, builder: (column) => column);

  GeneratedColumn<bool> get lowConfidence => $composableBuilder(
      column: $table.lowConfidence, builder: (column) => column);
}

class $$ItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ItemsTable,
    Item,
    $$ItemsTableFilterComposer,
    $$ItemsTableOrderingComposer,
    $$ItemsTableAnnotationComposer,
    $$ItemsTableCreateCompanionBuilder,
    $$ItemsTableUpdateCompanionBuilder,
    (Item, BaseReferences<_$AppDatabase, $ItemsTable, Item>),
    Item,
    PrefetchHooks Function()> {
  $$ItemsTableTableManager(_$AppDatabase db, $ItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> collegeId = const Value.absent(),
            Value<int> itemNumber = const Value.absent(),
            Value<String> rang = const Value.absent(),
            Value<String?> chapterTitle = const Value.absent(),
            Value<double> ocrConfidenceScore = const Value.absent(),
            Value<bool> lowConfidence = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemsCompanion(
            id: id,
            collegeId: collegeId,
            itemNumber: itemNumber,
            rang: rang,
            chapterTitle: chapterTitle,
            ocrConfidenceScore: ocrConfidenceScore,
            lowConfidence: lowConfidence,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String collegeId,
            required int itemNumber,
            required String rang,
            Value<String?> chapterTitle = const Value.absent(),
            Value<double> ocrConfidenceScore = const Value.absent(),
            Value<bool> lowConfidence = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ItemsCompanion.insert(
            id: id,
            collegeId: collegeId,
            itemNumber: itemNumber,
            rang: rang,
            chapterTitle: chapterTitle,
            ocrConfidenceScore: ocrConfidenceScore,
            lowConfidence: lowConfidence,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ItemsTable,
    Item,
    $$ItemsTableFilterComposer,
    $$ItemsTableOrderingComposer,
    $$ItemsTableAnnotationComposer,
    $$ItemsTableCreateCompanionBuilder,
    $$ItemsTableUpdateCompanionBuilder,
    (Item, BaseReferences<_$AppDatabase, $ItemsTable, Item>),
    Item,
    PrefetchHooks Function()>;
typedef $$FlashCardsTableCreateCompanionBuilder = FlashCardsCompanion Function({
  required String id,
  required String itemId,
  required String collegeId,
  required String cardType,
  required String rang,
  required String recto,
  required String verso,
  Value<double> ocrConfidenceScore,
  Value<bool> lowConfidence,
  Value<String?> userFeedback,
  Value<int> rowid,
});
typedef $$FlashCardsTableUpdateCompanionBuilder = FlashCardsCompanion Function({
  Value<String> id,
  Value<String> itemId,
  Value<String> collegeId,
  Value<String> cardType,
  Value<String> rang,
  Value<String> recto,
  Value<String> verso,
  Value<double> ocrConfidenceScore,
  Value<bool> lowConfidence,
  Value<String?> userFeedback,
  Value<int> rowid,
});

class $$FlashCardsTableFilterComposer
    extends Composer<_$AppDatabase, $FlashCardsTable> {
  $$FlashCardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collegeId => $composableBuilder(
      column: $table.collegeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cardType => $composableBuilder(
      column: $table.cardType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rang => $composableBuilder(
      column: $table.rang, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recto => $composableBuilder(
      column: $table.recto, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get verso => $composableBuilder(
      column: $table.verso, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get ocrConfidenceScore => $composableBuilder(
      column: $table.ocrConfidenceScore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get lowConfidence => $composableBuilder(
      column: $table.lowConfidence, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userFeedback => $composableBuilder(
      column: $table.userFeedback, builder: (column) => ColumnFilters(column));
}

class $$FlashCardsTableOrderingComposer
    extends Composer<_$AppDatabase, $FlashCardsTable> {
  $$FlashCardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId => $composableBuilder(
      column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collegeId => $composableBuilder(
      column: $table.collegeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cardType => $composableBuilder(
      column: $table.cardType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rang => $composableBuilder(
      column: $table.rang, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recto => $composableBuilder(
      column: $table.recto, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get verso => $composableBuilder(
      column: $table.verso, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get ocrConfidenceScore => $composableBuilder(
      column: $table.ocrConfidenceScore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get lowConfidence => $composableBuilder(
      column: $table.lowConfidence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userFeedback => $composableBuilder(
      column: $table.userFeedback,
      builder: (column) => ColumnOrderings(column));
}

class $$FlashCardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FlashCardsTable> {
  $$FlashCardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get collegeId =>
      $composableBuilder(column: $table.collegeId, builder: (column) => column);

  GeneratedColumn<String> get cardType =>
      $composableBuilder(column: $table.cardType, builder: (column) => column);

  GeneratedColumn<String> get rang =>
      $composableBuilder(column: $table.rang, builder: (column) => column);

  GeneratedColumn<String> get recto =>
      $composableBuilder(column: $table.recto, builder: (column) => column);

  GeneratedColumn<String> get verso =>
      $composableBuilder(column: $table.verso, builder: (column) => column);

  GeneratedColumn<double> get ocrConfidenceScore => $composableBuilder(
      column: $table.ocrConfidenceScore, builder: (column) => column);

  GeneratedColumn<bool> get lowConfidence => $composableBuilder(
      column: $table.lowConfidence, builder: (column) => column);

  GeneratedColumn<String> get userFeedback => $composableBuilder(
      column: $table.userFeedback, builder: (column) => column);
}

class $$FlashCardsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FlashCardsTable,
    FlashCard,
    $$FlashCardsTableFilterComposer,
    $$FlashCardsTableOrderingComposer,
    $$FlashCardsTableAnnotationComposer,
    $$FlashCardsTableCreateCompanionBuilder,
    $$FlashCardsTableUpdateCompanionBuilder,
    (FlashCard, BaseReferences<_$AppDatabase, $FlashCardsTable, FlashCard>),
    FlashCard,
    PrefetchHooks Function()> {
  $$FlashCardsTableTableManager(_$AppDatabase db, $FlashCardsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FlashCardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FlashCardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FlashCardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> itemId = const Value.absent(),
            Value<String> collegeId = const Value.absent(),
            Value<String> cardType = const Value.absent(),
            Value<String> rang = const Value.absent(),
            Value<String> recto = const Value.absent(),
            Value<String> verso = const Value.absent(),
            Value<double> ocrConfidenceScore = const Value.absent(),
            Value<bool> lowConfidence = const Value.absent(),
            Value<String?> userFeedback = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FlashCardsCompanion(
            id: id,
            itemId: itemId,
            collegeId: collegeId,
            cardType: cardType,
            rang: rang,
            recto: recto,
            verso: verso,
            ocrConfidenceScore: ocrConfidenceScore,
            lowConfidence: lowConfidence,
            userFeedback: userFeedback,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String itemId,
            required String collegeId,
            required String cardType,
            required String rang,
            required String recto,
            required String verso,
            Value<double> ocrConfidenceScore = const Value.absent(),
            Value<bool> lowConfidence = const Value.absent(),
            Value<String?> userFeedback = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FlashCardsCompanion.insert(
            id: id,
            itemId: itemId,
            collegeId: collegeId,
            cardType: cardType,
            rang: rang,
            recto: recto,
            verso: verso,
            ocrConfidenceScore: ocrConfidenceScore,
            lowConfidence: lowConfidence,
            userFeedback: userFeedback,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FlashCardsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FlashCardsTable,
    FlashCard,
    $$FlashCardsTableFilterComposer,
    $$FlashCardsTableOrderingComposer,
    $$FlashCardsTableAnnotationComposer,
    $$FlashCardsTableCreateCompanionBuilder,
    $$FlashCardsTableUpdateCompanionBuilder,
    (FlashCard, BaseReferences<_$AppDatabase, $FlashCardsTable, FlashCard>),
    FlashCard,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CollegeImportsTableTableManager get collegeImports =>
      $$CollegeImportsTableTableManager(_db, _db.collegeImports);
  $$ItemsTableTableManager get items =>
      $$ItemsTableTableManager(_db, _db.items);
  $$FlashCardsTableTableManager get flashCards =>
      $$FlashCardsTableTableManager(_db, _db.flashCards);
}
