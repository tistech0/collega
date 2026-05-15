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
  static const VerificationMeta _drillLevelMeta =
      const VerificationMeta('drillLevel');
  @override
  late final GeneratedColumn<String> drillLevel = GeneratedColumn<String>(
      'drill_level', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('new'));
  static const VerificationMeta _nextReviewAtMeta =
      const VerificationMeta('nextReviewAt');
  @override
  late final GeneratedColumn<int> nextReviewAt = GeneratedColumn<int>(
      'next_review_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _reviewCountMeta =
      const VerificationMeta('reviewCount');
  @override
  late final GeneratedColumn<int> reviewCount = GeneratedColumn<int>(
      'review_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
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
        userFeedback,
        drillLevel,
        nextReviewAt,
        reviewCount
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
    if (data.containsKey('drill_level')) {
      context.handle(
          _drillLevelMeta,
          drillLevel.isAcceptableOrUnknown(
              data['drill_level']!, _drillLevelMeta));
    }
    if (data.containsKey('next_review_at')) {
      context.handle(
          _nextReviewAtMeta,
          nextReviewAt.isAcceptableOrUnknown(
              data['next_review_at']!, _nextReviewAtMeta));
    }
    if (data.containsKey('review_count')) {
      context.handle(
          _reviewCountMeta,
          reviewCount.isAcceptableOrUnknown(
              data['review_count']!, _reviewCountMeta));
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
      drillLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drill_level'])!,
      nextReviewAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}next_review_at']),
      reviewCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}review_count'])!,
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
  final String drillLevel;
  final int? nextReviewAt;
  final int reviewCount;
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
      this.userFeedback,
      required this.drillLevel,
      this.nextReviewAt,
      required this.reviewCount});
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
    map['drill_level'] = Variable<String>(drillLevel);
    if (!nullToAbsent || nextReviewAt != null) {
      map['next_review_at'] = Variable<int>(nextReviewAt);
    }
    map['review_count'] = Variable<int>(reviewCount);
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
      drillLevel: Value(drillLevel),
      nextReviewAt: nextReviewAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextReviewAt),
      reviewCount: Value(reviewCount),
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
      drillLevel: serializer.fromJson<String>(json['drillLevel']),
      nextReviewAt: serializer.fromJson<int?>(json['nextReviewAt']),
      reviewCount: serializer.fromJson<int>(json['reviewCount']),
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
      'drillLevel': serializer.toJson<String>(drillLevel),
      'nextReviewAt': serializer.toJson<int?>(nextReviewAt),
      'reviewCount': serializer.toJson<int>(reviewCount),
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
          Value<String?> userFeedback = const Value.absent(),
          String? drillLevel,
          Value<int?> nextReviewAt = const Value.absent(),
          int? reviewCount}) =>
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
        drillLevel: drillLevel ?? this.drillLevel,
        nextReviewAt:
            nextReviewAt.present ? nextReviewAt.value : this.nextReviewAt,
        reviewCount: reviewCount ?? this.reviewCount,
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
      drillLevel:
          data.drillLevel.present ? data.drillLevel.value : this.drillLevel,
      nextReviewAt: data.nextReviewAt.present
          ? data.nextReviewAt.value
          : this.nextReviewAt,
      reviewCount:
          data.reviewCount.present ? data.reviewCount.value : this.reviewCount,
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
          ..write('userFeedback: $userFeedback, ')
          ..write('drillLevel: $drillLevel, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('reviewCount: $reviewCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      itemId,
      collegeId,
      cardType,
      rang,
      recto,
      verso,
      ocrConfidenceScore,
      lowConfidence,
      userFeedback,
      drillLevel,
      nextReviewAt,
      reviewCount);
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
          other.userFeedback == this.userFeedback &&
          other.drillLevel == this.drillLevel &&
          other.nextReviewAt == this.nextReviewAt &&
          other.reviewCount == this.reviewCount);
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
  final Value<String> drillLevel;
  final Value<int?> nextReviewAt;
  final Value<int> reviewCount;
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
    this.drillLevel = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.reviewCount = const Value.absent(),
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
    this.drillLevel = const Value.absent(),
    this.nextReviewAt = const Value.absent(),
    this.reviewCount = const Value.absent(),
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
    Expression<String>? drillLevel,
    Expression<int>? nextReviewAt,
    Expression<int>? reviewCount,
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
      if (drillLevel != null) 'drill_level': drillLevel,
      if (nextReviewAt != null) 'next_review_at': nextReviewAt,
      if (reviewCount != null) 'review_count': reviewCount,
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
      Value<String>? drillLevel,
      Value<int?>? nextReviewAt,
      Value<int>? reviewCount,
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
      drillLevel: drillLevel ?? this.drillLevel,
      nextReviewAt: nextReviewAt ?? this.nextReviewAt,
      reviewCount: reviewCount ?? this.reviewCount,
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
    if (drillLevel.present) {
      map['drill_level'] = Variable<String>(drillLevel.value);
    }
    if (nextReviewAt.present) {
      map['next_review_at'] = Variable<int>(nextReviewAt.value);
    }
    if (reviewCount.present) {
      map['review_count'] = Variable<int>(reviewCount.value);
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
          ..write('drillLevel: $drillLevel, ')
          ..write('nextReviewAt: $nextReviewAt, ')
          ..write('reviewCount: $reviewCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlanningConfigsTable extends PlanningConfigs
    with TableInfo<$PlanningConfigsTable, PlanningConfigRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanningConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _collegeIdsMeta =
      const VerificationMeta('collegeIds');
  @override
  late final GeneratedColumn<String> collegeIds = GeneratedColumn<String>(
      'college_ids', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _itemIdsMeta =
      const VerificationMeta('itemIds');
  @override
  late final GeneratedColumn<String> itemIds = GeneratedColumn<String>(
      'item_ids', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startDateEpochDayMeta =
      const VerificationMeta('startDateEpochDay');
  @override
  late final GeneratedColumn<int> startDateEpochDay = GeneratedColumn<int>(
      'start_date_epoch_day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _endDateEpochDayMeta =
      const VerificationMeta('endDateEpochDay');
  @override
  late final GeneratedColumn<int> endDateEpochDay = GeneratedColumn<int>(
      'end_date_epoch_day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dailyMinutesMeta =
      const VerificationMeta('dailyMinutes');
  @override
  late final GeneratedColumn<int> dailyMinutes = GeneratedColumn<int>(
      'daily_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMsMeta =
      const VerificationMeta('createdAtMs');
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
      'created_at_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        collegeIds,
        itemIds,
        startDateEpochDay,
        endDateEpochDay,
        dailyMinutes,
        createdAtMs
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'planning_configs';
  @override
  VerificationContext validateIntegrity(Insertable<PlanningConfigRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('college_ids')) {
      context.handle(
          _collegeIdsMeta,
          collegeIds.isAcceptableOrUnknown(
              data['college_ids']!, _collegeIdsMeta));
    } else if (isInserting) {
      context.missing(_collegeIdsMeta);
    }
    if (data.containsKey('item_ids')) {
      context.handle(_itemIdsMeta,
          itemIds.isAcceptableOrUnknown(data['item_ids']!, _itemIdsMeta));
    }
    if (data.containsKey('start_date_epoch_day')) {
      context.handle(
          _startDateEpochDayMeta,
          startDateEpochDay.isAcceptableOrUnknown(
              data['start_date_epoch_day']!, _startDateEpochDayMeta));
    } else if (isInserting) {
      context.missing(_startDateEpochDayMeta);
    }
    if (data.containsKey('end_date_epoch_day')) {
      context.handle(
          _endDateEpochDayMeta,
          endDateEpochDay.isAcceptableOrUnknown(
              data['end_date_epoch_day']!, _endDateEpochDayMeta));
    } else if (isInserting) {
      context.missing(_endDateEpochDayMeta);
    }
    if (data.containsKey('daily_minutes')) {
      context.handle(
          _dailyMinutesMeta,
          dailyMinutes.isAcceptableOrUnknown(
              data['daily_minutes']!, _dailyMinutesMeta));
    } else if (isInserting) {
      context.missing(_dailyMinutesMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
          _createdAtMsMeta,
          createdAtMs.isAcceptableOrUnknown(
              data['created_at_ms']!, _createdAtMsMeta));
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanningConfigRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanningConfigRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      collegeIds: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}college_ids'])!,
      itemIds: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}item_ids']),
      startDateEpochDay: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}start_date_epoch_day'])!,
      endDateEpochDay: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}end_date_epoch_day'])!,
      dailyMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}daily_minutes'])!,
      createdAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at_ms'])!,
    );
  }

  @override
  $PlanningConfigsTable createAlias(String alias) {
    return $PlanningConfigsTable(attachedDatabase, alias);
  }
}

class PlanningConfigRow extends DataClass
    implements Insertable<PlanningConfigRow> {
  final String id;
  final String collegeIds;
  final String? itemIds;
  final int startDateEpochDay;
  final int endDateEpochDay;
  final int dailyMinutes;
  final int createdAtMs;
  const PlanningConfigRow(
      {required this.id,
      required this.collegeIds,
      this.itemIds,
      required this.startDateEpochDay,
      required this.endDateEpochDay,
      required this.dailyMinutes,
      required this.createdAtMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['college_ids'] = Variable<String>(collegeIds);
    if (!nullToAbsent || itemIds != null) {
      map['item_ids'] = Variable<String>(itemIds);
    }
    map['start_date_epoch_day'] = Variable<int>(startDateEpochDay);
    map['end_date_epoch_day'] = Variable<int>(endDateEpochDay);
    map['daily_minutes'] = Variable<int>(dailyMinutes);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    return map;
  }

  PlanningConfigsCompanion toCompanion(bool nullToAbsent) {
    return PlanningConfigsCompanion(
      id: Value(id),
      collegeIds: Value(collegeIds),
      itemIds: itemIds == null && nullToAbsent
          ? const Value.absent()
          : Value(itemIds),
      startDateEpochDay: Value(startDateEpochDay),
      endDateEpochDay: Value(endDateEpochDay),
      dailyMinutes: Value(dailyMinutes),
      createdAtMs: Value(createdAtMs),
    );
  }

  factory PlanningConfigRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanningConfigRow(
      id: serializer.fromJson<String>(json['id']),
      collegeIds: serializer.fromJson<String>(json['collegeIds']),
      itemIds: serializer.fromJson<String?>(json['itemIds']),
      startDateEpochDay: serializer.fromJson<int>(json['startDateEpochDay']),
      endDateEpochDay: serializer.fromJson<int>(json['endDateEpochDay']),
      dailyMinutes: serializer.fromJson<int>(json['dailyMinutes']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'collegeIds': serializer.toJson<String>(collegeIds),
      'itemIds': serializer.toJson<String?>(itemIds),
      'startDateEpochDay': serializer.toJson<int>(startDateEpochDay),
      'endDateEpochDay': serializer.toJson<int>(endDateEpochDay),
      'dailyMinutes': serializer.toJson<int>(dailyMinutes),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
    };
  }

  PlanningConfigRow copyWith(
          {String? id,
          String? collegeIds,
          Value<String?> itemIds = const Value.absent(),
          int? startDateEpochDay,
          int? endDateEpochDay,
          int? dailyMinutes,
          int? createdAtMs}) =>
      PlanningConfigRow(
        id: id ?? this.id,
        collegeIds: collegeIds ?? this.collegeIds,
        itemIds: itemIds.present ? itemIds.value : this.itemIds,
        startDateEpochDay: startDateEpochDay ?? this.startDateEpochDay,
        endDateEpochDay: endDateEpochDay ?? this.endDateEpochDay,
        dailyMinutes: dailyMinutes ?? this.dailyMinutes,
        createdAtMs: createdAtMs ?? this.createdAtMs,
      );
  PlanningConfigRow copyWithCompanion(PlanningConfigsCompanion data) {
    return PlanningConfigRow(
      id: data.id.present ? data.id.value : this.id,
      collegeIds:
          data.collegeIds.present ? data.collegeIds.value : this.collegeIds,
      itemIds: data.itemIds.present ? data.itemIds.value : this.itemIds,
      startDateEpochDay: data.startDateEpochDay.present
          ? data.startDateEpochDay.value
          : this.startDateEpochDay,
      endDateEpochDay: data.endDateEpochDay.present
          ? data.endDateEpochDay.value
          : this.endDateEpochDay,
      dailyMinutes: data.dailyMinutes.present
          ? data.dailyMinutes.value
          : this.dailyMinutes,
      createdAtMs:
          data.createdAtMs.present ? data.createdAtMs.value : this.createdAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanningConfigRow(')
          ..write('id: $id, ')
          ..write('collegeIds: $collegeIds, ')
          ..write('itemIds: $itemIds, ')
          ..write('startDateEpochDay: $startDateEpochDay, ')
          ..write('endDateEpochDay: $endDateEpochDay, ')
          ..write('dailyMinutes: $dailyMinutes, ')
          ..write('createdAtMs: $createdAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, collegeIds, itemIds, startDateEpochDay,
      endDateEpochDay, dailyMinutes, createdAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanningConfigRow &&
          other.id == this.id &&
          other.collegeIds == this.collegeIds &&
          other.itemIds == this.itemIds &&
          other.startDateEpochDay == this.startDateEpochDay &&
          other.endDateEpochDay == this.endDateEpochDay &&
          other.dailyMinutes == this.dailyMinutes &&
          other.createdAtMs == this.createdAtMs);
}

class PlanningConfigsCompanion extends UpdateCompanion<PlanningConfigRow> {
  final Value<String> id;
  final Value<String> collegeIds;
  final Value<String?> itemIds;
  final Value<int> startDateEpochDay;
  final Value<int> endDateEpochDay;
  final Value<int> dailyMinutes;
  final Value<int> createdAtMs;
  final Value<int> rowid;
  const PlanningConfigsCompanion({
    this.id = const Value.absent(),
    this.collegeIds = const Value.absent(),
    this.itemIds = const Value.absent(),
    this.startDateEpochDay = const Value.absent(),
    this.endDateEpochDay = const Value.absent(),
    this.dailyMinutes = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanningConfigsCompanion.insert({
    required String id,
    required String collegeIds,
    this.itemIds = const Value.absent(),
    required int startDateEpochDay,
    required int endDateEpochDay,
    required int dailyMinutes,
    required int createdAtMs,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        collegeIds = Value(collegeIds),
        startDateEpochDay = Value(startDateEpochDay),
        endDateEpochDay = Value(endDateEpochDay),
        dailyMinutes = Value(dailyMinutes),
        createdAtMs = Value(createdAtMs);
  static Insertable<PlanningConfigRow> custom({
    Expression<String>? id,
    Expression<String>? collegeIds,
    Expression<String>? itemIds,
    Expression<int>? startDateEpochDay,
    Expression<int>? endDateEpochDay,
    Expression<int>? dailyMinutes,
    Expression<int>? createdAtMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (collegeIds != null) 'college_ids': collegeIds,
      if (itemIds != null) 'item_ids': itemIds,
      if (startDateEpochDay != null) 'start_date_epoch_day': startDateEpochDay,
      if (endDateEpochDay != null) 'end_date_epoch_day': endDateEpochDay,
      if (dailyMinutes != null) 'daily_minutes': dailyMinutes,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanningConfigsCompanion copyWith(
      {Value<String>? id,
      Value<String>? collegeIds,
      Value<String?>? itemIds,
      Value<int>? startDateEpochDay,
      Value<int>? endDateEpochDay,
      Value<int>? dailyMinutes,
      Value<int>? createdAtMs,
      Value<int>? rowid}) {
    return PlanningConfigsCompanion(
      id: id ?? this.id,
      collegeIds: collegeIds ?? this.collegeIds,
      itemIds: itemIds ?? this.itemIds,
      startDateEpochDay: startDateEpochDay ?? this.startDateEpochDay,
      endDateEpochDay: endDateEpochDay ?? this.endDateEpochDay,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (collegeIds.present) {
      map['college_ids'] = Variable<String>(collegeIds.value);
    }
    if (itemIds.present) {
      map['item_ids'] = Variable<String>(itemIds.value);
    }
    if (startDateEpochDay.present) {
      map['start_date_epoch_day'] = Variable<int>(startDateEpochDay.value);
    }
    if (endDateEpochDay.present) {
      map['end_date_epoch_day'] = Variable<int>(endDateEpochDay.value);
    }
    if (dailyMinutes.present) {
      map['daily_minutes'] = Variable<int>(dailyMinutes.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanningConfigsCompanion(')
          ..write('id: $id, ')
          ..write('collegeIds: $collegeIds, ')
          ..write('itemIds: $itemIds, ')
          ..write('startDateEpochDay: $startDateEpochDay, ')
          ..write('endDateEpochDay: $endDateEpochDay, ')
          ..write('dailyMinutes: $dailyMinutes, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlanningSessionsTable extends PlanningSessions
    with TableInfo<$PlanningSessionsTable, PlanningSessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanningSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planningConfigIdMeta =
      const VerificationMeta('planningConfigId');
  @override
  late final GeneratedColumn<String> planningConfigId = GeneratedColumn<String>(
      'planning_config_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionDateEpochDayMeta =
      const VerificationMeta('sessionDateEpochDay');
  @override
  late final GeneratedColumn<int> sessionDateEpochDay = GeneratedColumn<int>(
      'session_date_epoch_day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _collegeIdMeta =
      const VerificationMeta('collegeId');
  @override
  late final GeneratedColumn<String> collegeId = GeneratedColumn<String>(
      'college_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _maxCardsMeta =
      const VerificationMeta('maxCards');
  @override
  late final GeneratedColumn<int> maxCards = GeneratedColumn<int>(
      'max_cards', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, planningConfigId, sessionDateEpochDay, collegeId, maxCards, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'planning_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<PlanningSessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('planning_config_id')) {
      context.handle(
          _planningConfigIdMeta,
          planningConfigId.isAcceptableOrUnknown(
              data['planning_config_id']!, _planningConfigIdMeta));
    } else if (isInserting) {
      context.missing(_planningConfigIdMeta);
    }
    if (data.containsKey('session_date_epoch_day')) {
      context.handle(
          _sessionDateEpochDayMeta,
          sessionDateEpochDay.isAcceptableOrUnknown(
              data['session_date_epoch_day']!, _sessionDateEpochDayMeta));
    } else if (isInserting) {
      context.missing(_sessionDateEpochDayMeta);
    }
    if (data.containsKey('college_id')) {
      context.handle(_collegeIdMeta,
          collegeId.isAcceptableOrUnknown(data['college_id']!, _collegeIdMeta));
    } else if (isInserting) {
      context.missing(_collegeIdMeta);
    }
    if (data.containsKey('max_cards')) {
      context.handle(_maxCardsMeta,
          maxCards.isAcceptableOrUnknown(data['max_cards']!, _maxCardsMeta));
    } else if (isInserting) {
      context.missing(_maxCardsMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlanningSessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanningSessionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      planningConfigId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}planning_config_id'])!,
      sessionDateEpochDay: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}session_date_epoch_day'])!,
      collegeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}college_id'])!,
      maxCards: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_cards'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
    );
  }

  @override
  $PlanningSessionsTable createAlias(String alias) {
    return $PlanningSessionsTable(attachedDatabase, alias);
  }
}

class PlanningSessionRow extends DataClass
    implements Insertable<PlanningSessionRow> {
  final String id;
  final String planningConfigId;
  final int sessionDateEpochDay;
  final String collegeId;
  final int maxCards;
  final String status;
  const PlanningSessionRow(
      {required this.id,
      required this.planningConfigId,
      required this.sessionDateEpochDay,
      required this.collegeId,
      required this.maxCards,
      required this.status});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['planning_config_id'] = Variable<String>(planningConfigId);
    map['session_date_epoch_day'] = Variable<int>(sessionDateEpochDay);
    map['college_id'] = Variable<String>(collegeId);
    map['max_cards'] = Variable<int>(maxCards);
    map['status'] = Variable<String>(status);
    return map;
  }

  PlanningSessionsCompanion toCompanion(bool nullToAbsent) {
    return PlanningSessionsCompanion(
      id: Value(id),
      planningConfigId: Value(planningConfigId),
      sessionDateEpochDay: Value(sessionDateEpochDay),
      collegeId: Value(collegeId),
      maxCards: Value(maxCards),
      status: Value(status),
    );
  }

  factory PlanningSessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanningSessionRow(
      id: serializer.fromJson<String>(json['id']),
      planningConfigId: serializer.fromJson<String>(json['planningConfigId']),
      sessionDateEpochDay:
          serializer.fromJson<int>(json['sessionDateEpochDay']),
      collegeId: serializer.fromJson<String>(json['collegeId']),
      maxCards: serializer.fromJson<int>(json['maxCards']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'planningConfigId': serializer.toJson<String>(planningConfigId),
      'sessionDateEpochDay': serializer.toJson<int>(sessionDateEpochDay),
      'collegeId': serializer.toJson<String>(collegeId),
      'maxCards': serializer.toJson<int>(maxCards),
      'status': serializer.toJson<String>(status),
    };
  }

  PlanningSessionRow copyWith(
          {String? id,
          String? planningConfigId,
          int? sessionDateEpochDay,
          String? collegeId,
          int? maxCards,
          String? status}) =>
      PlanningSessionRow(
        id: id ?? this.id,
        planningConfigId: planningConfigId ?? this.planningConfigId,
        sessionDateEpochDay: sessionDateEpochDay ?? this.sessionDateEpochDay,
        collegeId: collegeId ?? this.collegeId,
        maxCards: maxCards ?? this.maxCards,
        status: status ?? this.status,
      );
  PlanningSessionRow copyWithCompanion(PlanningSessionsCompanion data) {
    return PlanningSessionRow(
      id: data.id.present ? data.id.value : this.id,
      planningConfigId: data.planningConfigId.present
          ? data.planningConfigId.value
          : this.planningConfigId,
      sessionDateEpochDay: data.sessionDateEpochDay.present
          ? data.sessionDateEpochDay.value
          : this.sessionDateEpochDay,
      collegeId: data.collegeId.present ? data.collegeId.value : this.collegeId,
      maxCards: data.maxCards.present ? data.maxCards.value : this.maxCards,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanningSessionRow(')
          ..write('id: $id, ')
          ..write('planningConfigId: $planningConfigId, ')
          ..write('sessionDateEpochDay: $sessionDateEpochDay, ')
          ..write('collegeId: $collegeId, ')
          ..write('maxCards: $maxCards, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, planningConfigId, sessionDateEpochDay, collegeId, maxCards, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanningSessionRow &&
          other.id == this.id &&
          other.planningConfigId == this.planningConfigId &&
          other.sessionDateEpochDay == this.sessionDateEpochDay &&
          other.collegeId == this.collegeId &&
          other.maxCards == this.maxCards &&
          other.status == this.status);
}

class PlanningSessionsCompanion extends UpdateCompanion<PlanningSessionRow> {
  final Value<String> id;
  final Value<String> planningConfigId;
  final Value<int> sessionDateEpochDay;
  final Value<String> collegeId;
  final Value<int> maxCards;
  final Value<String> status;
  final Value<int> rowid;
  const PlanningSessionsCompanion({
    this.id = const Value.absent(),
    this.planningConfigId = const Value.absent(),
    this.sessionDateEpochDay = const Value.absent(),
    this.collegeId = const Value.absent(),
    this.maxCards = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanningSessionsCompanion.insert({
    required String id,
    required String planningConfigId,
    required int sessionDateEpochDay,
    required String collegeId,
    required int maxCards,
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        planningConfigId = Value(planningConfigId),
        sessionDateEpochDay = Value(sessionDateEpochDay),
        collegeId = Value(collegeId),
        maxCards = Value(maxCards);
  static Insertable<PlanningSessionRow> custom({
    Expression<String>? id,
    Expression<String>? planningConfigId,
    Expression<int>? sessionDateEpochDay,
    Expression<String>? collegeId,
    Expression<int>? maxCards,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planningConfigId != null) 'planning_config_id': planningConfigId,
      if (sessionDateEpochDay != null)
        'session_date_epoch_day': sessionDateEpochDay,
      if (collegeId != null) 'college_id': collegeId,
      if (maxCards != null) 'max_cards': maxCards,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanningSessionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? planningConfigId,
      Value<int>? sessionDateEpochDay,
      Value<String>? collegeId,
      Value<int>? maxCards,
      Value<String>? status,
      Value<int>? rowid}) {
    return PlanningSessionsCompanion(
      id: id ?? this.id,
      planningConfigId: planningConfigId ?? this.planningConfigId,
      sessionDateEpochDay: sessionDateEpochDay ?? this.sessionDateEpochDay,
      collegeId: collegeId ?? this.collegeId,
      maxCards: maxCards ?? this.maxCards,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planningConfigId.present) {
      map['planning_config_id'] = Variable<String>(planningConfigId.value);
    }
    if (sessionDateEpochDay.present) {
      map['session_date_epoch_day'] = Variable<int>(sessionDateEpochDay.value);
    }
    if (collegeId.present) {
      map['college_id'] = Variable<String>(collegeId.value);
    }
    if (maxCards.present) {
      map['max_cards'] = Variable<int>(maxCards.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanningSessionsCompanion(')
          ..write('id: $id, ')
          ..write('planningConfigId: $planningConfigId, ')
          ..write('sessionDateEpochDay: $sessionDateEpochDay, ')
          ..write('collegeId: $collegeId, ')
          ..write('maxCards: $maxCards, ')
          ..write('status: $status, ')
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
  late final $PlanningConfigsTable planningConfigs =
      $PlanningConfigsTable(this);
  late final $PlanningSessionsTable planningSessions =
      $PlanningSessionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [collegeImports, items, flashCards, planningConfigs, planningSessions];
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
  Value<String> drillLevel,
  Value<int?> nextReviewAt,
  Value<int> reviewCount,
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
  Value<String> drillLevel,
  Value<int?> nextReviewAt,
  Value<int> reviewCount,
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

  ColumnFilters<String> get drillLevel => $composableBuilder(
      column: $table.drillLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get nextReviewAt => $composableBuilder(
      column: $table.nextReviewAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reviewCount => $composableBuilder(
      column: $table.reviewCount, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<String> get drillLevel => $composableBuilder(
      column: $table.drillLevel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get nextReviewAt => $composableBuilder(
      column: $table.nextReviewAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reviewCount => $composableBuilder(
      column: $table.reviewCount, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get drillLevel => $composableBuilder(
      column: $table.drillLevel, builder: (column) => column);

  GeneratedColumn<int> get nextReviewAt => $composableBuilder(
      column: $table.nextReviewAt, builder: (column) => column);

  GeneratedColumn<int> get reviewCount => $composableBuilder(
      column: $table.reviewCount, builder: (column) => column);
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
            Value<String> drillLevel = const Value.absent(),
            Value<int?> nextReviewAt = const Value.absent(),
            Value<int> reviewCount = const Value.absent(),
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
            drillLevel: drillLevel,
            nextReviewAt: nextReviewAt,
            reviewCount: reviewCount,
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
            Value<String> drillLevel = const Value.absent(),
            Value<int?> nextReviewAt = const Value.absent(),
            Value<int> reviewCount = const Value.absent(),
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
            drillLevel: drillLevel,
            nextReviewAt: nextReviewAt,
            reviewCount: reviewCount,
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
typedef $$PlanningConfigsTableCreateCompanionBuilder = PlanningConfigsCompanion
    Function({
  required String id,
  required String collegeIds,
  Value<String?> itemIds,
  required int startDateEpochDay,
  required int endDateEpochDay,
  required int dailyMinutes,
  required int createdAtMs,
  Value<int> rowid,
});
typedef $$PlanningConfigsTableUpdateCompanionBuilder = PlanningConfigsCompanion
    Function({
  Value<String> id,
  Value<String> collegeIds,
  Value<String?> itemIds,
  Value<int> startDateEpochDay,
  Value<int> endDateEpochDay,
  Value<int> dailyMinutes,
  Value<int> createdAtMs,
  Value<int> rowid,
});

class $$PlanningConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $PlanningConfigsTable> {
  $$PlanningConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collegeIds => $composableBuilder(
      column: $table.collegeIds, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemIds => $composableBuilder(
      column: $table.itemIds, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startDateEpochDay => $composableBuilder(
      column: $table.startDateEpochDay,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endDateEpochDay => $composableBuilder(
      column: $table.endDateEpochDay,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyMinutes => $composableBuilder(
      column: $table.dailyMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => ColumnFilters(column));
}

class $$PlanningConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanningConfigsTable> {
  $$PlanningConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collegeIds => $composableBuilder(
      column: $table.collegeIds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemIds => $composableBuilder(
      column: $table.itemIds, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startDateEpochDay => $composableBuilder(
      column: $table.startDateEpochDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endDateEpochDay => $composableBuilder(
      column: $table.endDateEpochDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dailyMinutes => $composableBuilder(
      column: $table.dailyMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => ColumnOrderings(column));
}

class $$PlanningConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanningConfigsTable> {
  $$PlanningConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get collegeIds => $composableBuilder(
      column: $table.collegeIds, builder: (column) => column);

  GeneratedColumn<String> get itemIds =>
      $composableBuilder(column: $table.itemIds, builder: (column) => column);

  GeneratedColumn<int> get startDateEpochDay => $composableBuilder(
      column: $table.startDateEpochDay, builder: (column) => column);

  GeneratedColumn<int> get endDateEpochDay => $composableBuilder(
      column: $table.endDateEpochDay, builder: (column) => column);

  GeneratedColumn<int> get dailyMinutes => $composableBuilder(
      column: $table.dailyMinutes, builder: (column) => column);

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
      column: $table.createdAtMs, builder: (column) => column);
}

class $$PlanningConfigsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlanningConfigsTable,
    PlanningConfigRow,
    $$PlanningConfigsTableFilterComposer,
    $$PlanningConfigsTableOrderingComposer,
    $$PlanningConfigsTableAnnotationComposer,
    $$PlanningConfigsTableCreateCompanionBuilder,
    $$PlanningConfigsTableUpdateCompanionBuilder,
    (
      PlanningConfigRow,
      BaseReferences<_$AppDatabase, $PlanningConfigsTable, PlanningConfigRow>
    ),
    PlanningConfigRow,
    PrefetchHooks Function()> {
  $$PlanningConfigsTableTableManager(
      _$AppDatabase db, $PlanningConfigsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanningConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanningConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanningConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> collegeIds = const Value.absent(),
            Value<String?> itemIds = const Value.absent(),
            Value<int> startDateEpochDay = const Value.absent(),
            Value<int> endDateEpochDay = const Value.absent(),
            Value<int> dailyMinutes = const Value.absent(),
            Value<int> createdAtMs = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlanningConfigsCompanion(
            id: id,
            collegeIds: collegeIds,
            itemIds: itemIds,
            startDateEpochDay: startDateEpochDay,
            endDateEpochDay: endDateEpochDay,
            dailyMinutes: dailyMinutes,
            createdAtMs: createdAtMs,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String collegeIds,
            Value<String?> itemIds = const Value.absent(),
            required int startDateEpochDay,
            required int endDateEpochDay,
            required int dailyMinutes,
            required int createdAtMs,
            Value<int> rowid = const Value.absent(),
          }) =>
              PlanningConfigsCompanion.insert(
            id: id,
            collegeIds: collegeIds,
            itemIds: itemIds,
            startDateEpochDay: startDateEpochDay,
            endDateEpochDay: endDateEpochDay,
            dailyMinutes: dailyMinutes,
            createdAtMs: createdAtMs,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlanningConfigsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlanningConfigsTable,
    PlanningConfigRow,
    $$PlanningConfigsTableFilterComposer,
    $$PlanningConfigsTableOrderingComposer,
    $$PlanningConfigsTableAnnotationComposer,
    $$PlanningConfigsTableCreateCompanionBuilder,
    $$PlanningConfigsTableUpdateCompanionBuilder,
    (
      PlanningConfigRow,
      BaseReferences<_$AppDatabase, $PlanningConfigsTable, PlanningConfigRow>
    ),
    PlanningConfigRow,
    PrefetchHooks Function()>;
typedef $$PlanningSessionsTableCreateCompanionBuilder
    = PlanningSessionsCompanion Function({
  required String id,
  required String planningConfigId,
  required int sessionDateEpochDay,
  required String collegeId,
  required int maxCards,
  Value<String> status,
  Value<int> rowid,
});
typedef $$PlanningSessionsTableUpdateCompanionBuilder
    = PlanningSessionsCompanion Function({
  Value<String> id,
  Value<String> planningConfigId,
  Value<int> sessionDateEpochDay,
  Value<String> collegeId,
  Value<int> maxCards,
  Value<String> status,
  Value<int> rowid,
});

class $$PlanningSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $PlanningSessionsTable> {
  $$PlanningSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planningConfigId => $composableBuilder(
      column: $table.planningConfigId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sessionDateEpochDay => $composableBuilder(
      column: $table.sessionDateEpochDay,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collegeId => $composableBuilder(
      column: $table.collegeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxCards => $composableBuilder(
      column: $table.maxCards, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));
}

class $$PlanningSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanningSessionsTable> {
  $$PlanningSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planningConfigId => $composableBuilder(
      column: $table.planningConfigId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sessionDateEpochDay => $composableBuilder(
      column: $table.sessionDateEpochDay,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collegeId => $composableBuilder(
      column: $table.collegeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxCards => $composableBuilder(
      column: $table.maxCards, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));
}

class $$PlanningSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanningSessionsTable> {
  $$PlanningSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get planningConfigId => $composableBuilder(
      column: $table.planningConfigId, builder: (column) => column);

  GeneratedColumn<int> get sessionDateEpochDay => $composableBuilder(
      column: $table.sessionDateEpochDay, builder: (column) => column);

  GeneratedColumn<String> get collegeId =>
      $composableBuilder(column: $table.collegeId, builder: (column) => column);

  GeneratedColumn<int> get maxCards =>
      $composableBuilder(column: $table.maxCards, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$PlanningSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlanningSessionsTable,
    PlanningSessionRow,
    $$PlanningSessionsTableFilterComposer,
    $$PlanningSessionsTableOrderingComposer,
    $$PlanningSessionsTableAnnotationComposer,
    $$PlanningSessionsTableCreateCompanionBuilder,
    $$PlanningSessionsTableUpdateCompanionBuilder,
    (
      PlanningSessionRow,
      BaseReferences<_$AppDatabase, $PlanningSessionsTable, PlanningSessionRow>
    ),
    PlanningSessionRow,
    PrefetchHooks Function()> {
  $$PlanningSessionsTableTableManager(
      _$AppDatabase db, $PlanningSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanningSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanningSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanningSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> planningConfigId = const Value.absent(),
            Value<int> sessionDateEpochDay = const Value.absent(),
            Value<String> collegeId = const Value.absent(),
            Value<int> maxCards = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlanningSessionsCompanion(
            id: id,
            planningConfigId: planningConfigId,
            sessionDateEpochDay: sessionDateEpochDay,
            collegeId: collegeId,
            maxCards: maxCards,
            status: status,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String planningConfigId,
            required int sessionDateEpochDay,
            required String collegeId,
            required int maxCards,
            Value<String> status = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlanningSessionsCompanion.insert(
            id: id,
            planningConfigId: planningConfigId,
            sessionDateEpochDay: sessionDateEpochDay,
            collegeId: collegeId,
            maxCards: maxCards,
            status: status,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlanningSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlanningSessionsTable,
    PlanningSessionRow,
    $$PlanningSessionsTableFilterComposer,
    $$PlanningSessionsTableOrderingComposer,
    $$PlanningSessionsTableAnnotationComposer,
    $$PlanningSessionsTableCreateCompanionBuilder,
    $$PlanningSessionsTableUpdateCompanionBuilder,
    (
      PlanningSessionRow,
      BaseReferences<_$AppDatabase, $PlanningSessionsTable, PlanningSessionRow>
    ),
    PlanningSessionRow,
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
  $$PlanningConfigsTableTableManager get planningConfigs =>
      $$PlanningConfigsTableTableManager(_db, _db.planningConfigs);
  $$PlanningSessionsTableTableManager get planningSessions =>
      $$PlanningSessionsTableTableManager(_db, _db.planningSessions);
}
