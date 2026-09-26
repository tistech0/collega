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
  static const VerificationMeta _startPageMeta =
      const VerificationMeta('startPage');
  @override
  late final GeneratedColumn<int> startPage = GeneratedColumn<int>(
      'start_page', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _endPageMeta =
      const VerificationMeta('endPage');
  @override
  late final GeneratedColumn<int> endPage = GeneratedColumn<int>(
      'end_page', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        collegeId,
        itemNumber,
        rang,
        chapterTitle,
        ocrConfidenceScore,
        lowConfidence,
        startPage,
        endPage
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
    if (data.containsKey('start_page')) {
      context.handle(_startPageMeta,
          startPage.isAcceptableOrUnknown(data['start_page']!, _startPageMeta));
    }
    if (data.containsKey('end_page')) {
      context.handle(_endPageMeta,
          endPage.isAcceptableOrUnknown(data['end_page']!, _endPageMeta));
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
      startPage: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}start_page']),
      endPage: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}end_page']),
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

  /// Pages de l'item dans le PDF, base 0 (partie B) ; null pour un import ancien.
  final int? startPage;
  final int? endPage;
  const Item(
      {required this.id,
      required this.collegeId,
      required this.itemNumber,
      required this.rang,
      this.chapterTitle,
      required this.ocrConfidenceScore,
      required this.lowConfidence,
      this.startPage,
      this.endPage});
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
    if (!nullToAbsent || startPage != null) {
      map['start_page'] = Variable<int>(startPage);
    }
    if (!nullToAbsent || endPage != null) {
      map['end_page'] = Variable<int>(endPage);
    }
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
      startPage: startPage == null && nullToAbsent
          ? const Value.absent()
          : Value(startPage),
      endPage: endPage == null && nullToAbsent
          ? const Value.absent()
          : Value(endPage),
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
      startPage: serializer.fromJson<int?>(json['startPage']),
      endPage: serializer.fromJson<int?>(json['endPage']),
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
      'startPage': serializer.toJson<int?>(startPage),
      'endPage': serializer.toJson<int?>(endPage),
    };
  }

  Item copyWith(
          {String? id,
          String? collegeId,
          int? itemNumber,
          String? rang,
          Value<String?> chapterTitle = const Value.absent(),
          double? ocrConfidenceScore,
          bool? lowConfidence,
          Value<int?> startPage = const Value.absent(),
          Value<int?> endPage = const Value.absent()}) =>
      Item(
        id: id ?? this.id,
        collegeId: collegeId ?? this.collegeId,
        itemNumber: itemNumber ?? this.itemNumber,
        rang: rang ?? this.rang,
        chapterTitle:
            chapterTitle.present ? chapterTitle.value : this.chapterTitle,
        ocrConfidenceScore: ocrConfidenceScore ?? this.ocrConfidenceScore,
        lowConfidence: lowConfidence ?? this.lowConfidence,
        startPage: startPage.present ? startPage.value : this.startPage,
        endPage: endPage.present ? endPage.value : this.endPage,
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
      startPage: data.startPage.present ? data.startPage.value : this.startPage,
      endPage: data.endPage.present ? data.endPage.value : this.endPage,
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
          ..write('lowConfidence: $lowConfidence, ')
          ..write('startPage: $startPage, ')
          ..write('endPage: $endPage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, collegeId, itemNumber, rang, chapterTitle,
      ocrConfidenceScore, lowConfidence, startPage, endPage);
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
          other.lowConfidence == this.lowConfidence &&
          other.startPage == this.startPage &&
          other.endPage == this.endPage);
}

class ItemsCompanion extends UpdateCompanion<Item> {
  final Value<String> id;
  final Value<String> collegeId;
  final Value<int> itemNumber;
  final Value<String> rang;
  final Value<String?> chapterTitle;
  final Value<double> ocrConfidenceScore;
  final Value<bool> lowConfidence;
  final Value<int?> startPage;
  final Value<int?> endPage;
  final Value<int> rowid;
  const ItemsCompanion({
    this.id = const Value.absent(),
    this.collegeId = const Value.absent(),
    this.itemNumber = const Value.absent(),
    this.rang = const Value.absent(),
    this.chapterTitle = const Value.absent(),
    this.ocrConfidenceScore = const Value.absent(),
    this.lowConfidence = const Value.absent(),
    this.startPage = const Value.absent(),
    this.endPage = const Value.absent(),
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
    this.startPage = const Value.absent(),
    this.endPage = const Value.absent(),
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
    Expression<int>? startPage,
    Expression<int>? endPage,
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
      if (startPage != null) 'start_page': startPage,
      if (endPage != null) 'end_page': endPage,
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
      Value<int?>? startPage,
      Value<int?>? endPage,
      Value<int>? rowid}) {
    return ItemsCompanion(
      id: id ?? this.id,
      collegeId: collegeId ?? this.collegeId,
      itemNumber: itemNumber ?? this.itemNumber,
      rang: rang ?? this.rang,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      ocrConfidenceScore: ocrConfidenceScore ?? this.ocrConfidenceScore,
      lowConfidence: lowConfidence ?? this.lowConfidence,
      startPage: startPage ?? this.startPage,
      endPage: endPage ?? this.endPage,
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
    if (startPage.present) {
      map['start_page'] = Variable<int>(startPage.value);
    }
    if (endPage.present) {
      map['end_page'] = Variable<int>(endPage.value);
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
          ..write('startPage: $startPage, ')
          ..write('endPage: $endPage, ')
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

class $PendingUploadsTable extends PendingUploads
    with TableInfo<$PendingUploadsTable, PendingUpload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingUploadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uploadIdMeta =
      const VerificationMeta('uploadId');
  @override
  late final GeneratedColumn<String> uploadId = GeneratedColumn<String>(
      'upload_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  @override
  late final GeneratedColumn<int> refId = GeneratedColumn<int>(
      'ref_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _partSizeMeta =
      const VerificationMeta('partSize');
  @override
  late final GeneratedColumn<int> partSize = GeneratedColumn<int>(
      'part_size', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _partsTotalMeta =
      const VerificationMeta('partsTotal');
  @override
  late final GeneratedColumn<int> partsTotal = GeneratedColumn<int>(
      'parts_total', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [uploadId, refId, filePath, sizeBytes, partSize, partsTotal, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_uploads';
  @override
  VerificationContext validateIntegrity(Insertable<PendingUpload> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('upload_id')) {
      context.handle(_uploadIdMeta,
          uploadId.isAcceptableOrUnknown(data['upload_id']!, _uploadIdMeta));
    } else if (isInserting) {
      context.missing(_uploadIdMeta);
    }
    if (data.containsKey('ref_id')) {
      context.handle(
          _refIdMeta, refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta));
    } else if (isInserting) {
      context.missing(_refIdMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('part_size')) {
      context.handle(_partSizeMeta,
          partSize.isAcceptableOrUnknown(data['part_size']!, _partSizeMeta));
    } else if (isInserting) {
      context.missing(_partSizeMeta);
    }
    if (data.containsKey('parts_total')) {
      context.handle(
          _partsTotalMeta,
          partsTotal.isAcceptableOrUnknown(
              data['parts_total']!, _partsTotalMeta));
    } else if (isInserting) {
      context.missing(_partsTotalMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uploadId};
  @override
  PendingUpload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingUpload(
      uploadId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}upload_id'])!,
      refId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ref_id'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      partSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}part_size'])!,
      partsTotal: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}parts_total'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $PendingUploadsTable createAlias(String alias) {
    return $PendingUploadsTable(attachedDatabase, alias);
  }
}

class PendingUpload extends DataClass implements Insertable<PendingUpload> {
  final String uploadId;
  final int refId;
  final String filePath;
  final int sizeBytes;
  final int partSize;
  final int partsTotal;
  final DateTime createdAt;
  const PendingUpload(
      {required this.uploadId,
      required this.refId,
      required this.filePath,
      required this.sizeBytes,
      required this.partSize,
      required this.partsTotal,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['upload_id'] = Variable<String>(uploadId);
    map['ref_id'] = Variable<int>(refId);
    map['file_path'] = Variable<String>(filePath);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['part_size'] = Variable<int>(partSize);
    map['parts_total'] = Variable<int>(partsTotal);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingUploadsCompanion toCompanion(bool nullToAbsent) {
    return PendingUploadsCompanion(
      uploadId: Value(uploadId),
      refId: Value(refId),
      filePath: Value(filePath),
      sizeBytes: Value(sizeBytes),
      partSize: Value(partSize),
      partsTotal: Value(partsTotal),
      createdAt: Value(createdAt),
    );
  }

  factory PendingUpload.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingUpload(
      uploadId: serializer.fromJson<String>(json['uploadId']),
      refId: serializer.fromJson<int>(json['refId']),
      filePath: serializer.fromJson<String>(json['filePath']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      partSize: serializer.fromJson<int>(json['partSize']),
      partsTotal: serializer.fromJson<int>(json['partsTotal']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uploadId': serializer.toJson<String>(uploadId),
      'refId': serializer.toJson<int>(refId),
      'filePath': serializer.toJson<String>(filePath),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'partSize': serializer.toJson<int>(partSize),
      'partsTotal': serializer.toJson<int>(partsTotal),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingUpload copyWith(
          {String? uploadId,
          int? refId,
          String? filePath,
          int? sizeBytes,
          int? partSize,
          int? partsTotal,
          DateTime? createdAt}) =>
      PendingUpload(
        uploadId: uploadId ?? this.uploadId,
        refId: refId ?? this.refId,
        filePath: filePath ?? this.filePath,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        partSize: partSize ?? this.partSize,
        partsTotal: partsTotal ?? this.partsTotal,
        createdAt: createdAt ?? this.createdAt,
      );
  PendingUpload copyWithCompanion(PendingUploadsCompanion data) {
    return PendingUpload(
      uploadId: data.uploadId.present ? data.uploadId.value : this.uploadId,
      refId: data.refId.present ? data.refId.value : this.refId,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      partSize: data.partSize.present ? data.partSize.value : this.partSize,
      partsTotal:
          data.partsTotal.present ? data.partsTotal.value : this.partsTotal,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingUpload(')
          ..write('uploadId: $uploadId, ')
          ..write('refId: $refId, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('partSize: $partSize, ')
          ..write('partsTotal: $partsTotal, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      uploadId, refId, filePath, sizeBytes, partSize, partsTotal, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingUpload &&
          other.uploadId == this.uploadId &&
          other.refId == this.refId &&
          other.filePath == this.filePath &&
          other.sizeBytes == this.sizeBytes &&
          other.partSize == this.partSize &&
          other.partsTotal == this.partsTotal &&
          other.createdAt == this.createdAt);
}

class PendingUploadsCompanion extends UpdateCompanion<PendingUpload> {
  final Value<String> uploadId;
  final Value<int> refId;
  final Value<String> filePath;
  final Value<int> sizeBytes;
  final Value<int> partSize;
  final Value<int> partsTotal;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const PendingUploadsCompanion({
    this.uploadId = const Value.absent(),
    this.refId = const Value.absent(),
    this.filePath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.partSize = const Value.absent(),
    this.partsTotal = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingUploadsCompanion.insert({
    required String uploadId,
    required int refId,
    required String filePath,
    required int sizeBytes,
    required int partSize,
    required int partsTotal,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : uploadId = Value(uploadId),
        refId = Value(refId),
        filePath = Value(filePath),
        sizeBytes = Value(sizeBytes),
        partSize = Value(partSize),
        partsTotal = Value(partsTotal),
        createdAt = Value(createdAt);
  static Insertable<PendingUpload> custom({
    Expression<String>? uploadId,
    Expression<int>? refId,
    Expression<String>? filePath,
    Expression<int>? sizeBytes,
    Expression<int>? partSize,
    Expression<int>? partsTotal,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uploadId != null) 'upload_id': uploadId,
      if (refId != null) 'ref_id': refId,
      if (filePath != null) 'file_path': filePath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (partSize != null) 'part_size': partSize,
      if (partsTotal != null) 'parts_total': partsTotal,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingUploadsCompanion copyWith(
      {Value<String>? uploadId,
      Value<int>? refId,
      Value<String>? filePath,
      Value<int>? sizeBytes,
      Value<int>? partSize,
      Value<int>? partsTotal,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return PendingUploadsCompanion(
      uploadId: uploadId ?? this.uploadId,
      refId: refId ?? this.refId,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      partSize: partSize ?? this.partSize,
      partsTotal: partsTotal ?? this.partsTotal,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uploadId.present) {
      map['upload_id'] = Variable<String>(uploadId.value);
    }
    if (refId.present) {
      map['ref_id'] = Variable<int>(refId.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (partSize.present) {
      map['part_size'] = Variable<int>(partSize.value);
    }
    if (partsTotal.present) {
      map['parts_total'] = Variable<int>(partsTotal.value);
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
    return (StringBuffer('PendingUploadsCompanion(')
          ..write('uploadId: $uploadId, ')
          ..write('refId: $refId, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('partSize: $partSize, ')
          ..write('partsTotal: $partsTotal, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailySessionsTable extends DailySessions
    with TableInfo<$DailySessionsTable, DailySessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailySessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
      'day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _queueJsonMeta =
      const VerificationMeta('queueJson');
  @override
  late final GeneratedColumn<String> queueJson = GeneratedColumn<String>(
      'queue_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _settingsJsonMeta =
      const VerificationMeta('settingsJson');
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
      'settings_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _startedAtMsMeta =
      const VerificationMeta('startedAtMs');
  @override
  late final GeneratedColumn<int> startedAtMs = GeneratedColumn<int>(
      'started_at_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _completedAtMsMeta =
      const VerificationMeta('completedAtMs');
  @override
  late final GeneratedColumn<int> completedAtMs = GeneratedColumn<int>(
      'completed_at_ms', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [day, queueJson, position, settingsJson, startedAtMs, completedAtMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<DailySessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    }
    if (data.containsKey('queue_json')) {
      context.handle(_queueJsonMeta,
          queueJson.isAcceptableOrUnknown(data['queue_json']!, _queueJsonMeta));
    } else if (isInserting) {
      context.missing(_queueJsonMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('settings_json')) {
      context.handle(
          _settingsJsonMeta,
          settingsJson.isAcceptableOrUnknown(
              data['settings_json']!, _settingsJsonMeta));
    }
    if (data.containsKey('started_at_ms')) {
      context.handle(
          _startedAtMsMeta,
          startedAtMs.isAcceptableOrUnknown(
              data['started_at_ms']!, _startedAtMsMeta));
    }
    if (data.containsKey('completed_at_ms')) {
      context.handle(
          _completedAtMsMeta,
          completedAtMs.isAcceptableOrUnknown(
              data['completed_at_ms']!, _completedAtMsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  DailySessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailySessionRow(
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day'])!,
      queueJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}queue_json'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      settingsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}settings_json']),
      startedAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}started_at_ms']),
      completedAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completed_at_ms']),
    );
  }

  @override
  $DailySessionsTable createAlias(String alias) {
    return $DailySessionsTable(attachedDatabase, alias);
  }
}

class DailySessionRow extends DataClass implements Insertable<DailySessionRow> {
  /// Jour local (`epochDayOf`).
  final int day;

  /// File des ids de fiches (JSON), réinsertions « à revoir » comprises.
  final String queueJson;

  /// Nombre de fiches jugées.
  final int position;

  /// Réglages « Personnaliser » (JSON), null = session calculée par défaut.
  final String? settingsJson;
  final int? startedAtMs;
  final int? completedAtMs;
  const DailySessionRow(
      {required this.day,
      required this.queueJson,
      required this.position,
      this.settingsJson,
      this.startedAtMs,
      this.completedAtMs});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<int>(day);
    map['queue_json'] = Variable<String>(queueJson);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || settingsJson != null) {
      map['settings_json'] = Variable<String>(settingsJson);
    }
    if (!nullToAbsent || startedAtMs != null) {
      map['started_at_ms'] = Variable<int>(startedAtMs);
    }
    if (!nullToAbsent || completedAtMs != null) {
      map['completed_at_ms'] = Variable<int>(completedAtMs);
    }
    return map;
  }

  DailySessionsCompanion toCompanion(bool nullToAbsent) {
    return DailySessionsCompanion(
      day: Value(day),
      queueJson: Value(queueJson),
      position: Value(position),
      settingsJson: settingsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(settingsJson),
      startedAtMs: startedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAtMs),
      completedAtMs: completedAtMs == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtMs),
    );
  }

  factory DailySessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailySessionRow(
      day: serializer.fromJson<int>(json['day']),
      queueJson: serializer.fromJson<String>(json['queueJson']),
      position: serializer.fromJson<int>(json['position']),
      settingsJson: serializer.fromJson<String?>(json['settingsJson']),
      startedAtMs: serializer.fromJson<int?>(json['startedAtMs']),
      completedAtMs: serializer.fromJson<int?>(json['completedAtMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<int>(day),
      'queueJson': serializer.toJson<String>(queueJson),
      'position': serializer.toJson<int>(position),
      'settingsJson': serializer.toJson<String?>(settingsJson),
      'startedAtMs': serializer.toJson<int?>(startedAtMs),
      'completedAtMs': serializer.toJson<int?>(completedAtMs),
    };
  }

  DailySessionRow copyWith(
          {int? day,
          String? queueJson,
          int? position,
          Value<String?> settingsJson = const Value.absent(),
          Value<int?> startedAtMs = const Value.absent(),
          Value<int?> completedAtMs = const Value.absent()}) =>
      DailySessionRow(
        day: day ?? this.day,
        queueJson: queueJson ?? this.queueJson,
        position: position ?? this.position,
        settingsJson:
            settingsJson.present ? settingsJson.value : this.settingsJson,
        startedAtMs: startedAtMs.present ? startedAtMs.value : this.startedAtMs,
        completedAtMs:
            completedAtMs.present ? completedAtMs.value : this.completedAtMs,
      );
  DailySessionRow copyWithCompanion(DailySessionsCompanion data) {
    return DailySessionRow(
      day: data.day.present ? data.day.value : this.day,
      queueJson: data.queueJson.present ? data.queueJson.value : this.queueJson,
      position: data.position.present ? data.position.value : this.position,
      settingsJson: data.settingsJson.present
          ? data.settingsJson.value
          : this.settingsJson,
      startedAtMs:
          data.startedAtMs.present ? data.startedAtMs.value : this.startedAtMs,
      completedAtMs: data.completedAtMs.present
          ? data.completedAtMs.value
          : this.completedAtMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailySessionRow(')
          ..write('day: $day, ')
          ..write('queueJson: $queueJson, ')
          ..write('position: $position, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('completedAtMs: $completedAtMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      day, queueJson, position, settingsJson, startedAtMs, completedAtMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailySessionRow &&
          other.day == this.day &&
          other.queueJson == this.queueJson &&
          other.position == this.position &&
          other.settingsJson == this.settingsJson &&
          other.startedAtMs == this.startedAtMs &&
          other.completedAtMs == this.completedAtMs);
}

class DailySessionsCompanion extends UpdateCompanion<DailySessionRow> {
  final Value<int> day;
  final Value<String> queueJson;
  final Value<int> position;
  final Value<String?> settingsJson;
  final Value<int?> startedAtMs;
  final Value<int?> completedAtMs;
  const DailySessionsCompanion({
    this.day = const Value.absent(),
    this.queueJson = const Value.absent(),
    this.position = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.completedAtMs = const Value.absent(),
  });
  DailySessionsCompanion.insert({
    this.day = const Value.absent(),
    required String queueJson,
    this.position = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.startedAtMs = const Value.absent(),
    this.completedAtMs = const Value.absent(),
  }) : queueJson = Value(queueJson);
  static Insertable<DailySessionRow> custom({
    Expression<int>? day,
    Expression<String>? queueJson,
    Expression<int>? position,
    Expression<String>? settingsJson,
    Expression<int>? startedAtMs,
    Expression<int>? completedAtMs,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (queueJson != null) 'queue_json': queueJson,
      if (position != null) 'position': position,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (startedAtMs != null) 'started_at_ms': startedAtMs,
      if (completedAtMs != null) 'completed_at_ms': completedAtMs,
    });
  }

  DailySessionsCompanion copyWith(
      {Value<int>? day,
      Value<String>? queueJson,
      Value<int>? position,
      Value<String?>? settingsJson,
      Value<int?>? startedAtMs,
      Value<int?>? completedAtMs}) {
    return DailySessionsCompanion(
      day: day ?? this.day,
      queueJson: queueJson ?? this.queueJson,
      position: position ?? this.position,
      settingsJson: settingsJson ?? this.settingsJson,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      completedAtMs: completedAtMs ?? this.completedAtMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (queueJson.present) {
      map['queue_json'] = Variable<String>(queueJson.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
    }
    if (startedAtMs.present) {
      map['started_at_ms'] = Variable<int>(startedAtMs.value);
    }
    if (completedAtMs.present) {
      map['completed_at_ms'] = Variable<int>(completedAtMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailySessionsCompanion(')
          ..write('day: $day, ')
          ..write('queueJson: $queueJson, ')
          ..write('position: $position, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('startedAtMs: $startedAtMs, ')
          ..write('completedAtMs: $completedAtMs')
          ..write(')'))
        .toString();
  }
}

class $ReviewLogTable extends ReviewLog
    with TableInfo<$ReviewLogTable, ReviewLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReviewLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
      'card_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _collegeIdMeta =
      const VerificationMeta('collegeId');
  @override
  late final GeneratedColumn<String> collegeId = GeneratedColumn<String>(
      'college_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rangMeta = const VerificationMeta('rang');
  @override
  late final GeneratedColumn<String> rang = GeneratedColumn<String>(
      'rang', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _drillLevelMeta =
      const VerificationMeta('drillLevel');
  @override
  late final GeneratedColumn<String> drillLevel = GeneratedColumn<String>(
      'drill_level', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reviewedAtMsMeta =
      const VerificationMeta('reviewedAtMs');
  @override
  late final GeneratedColumn<int> reviewedAtMs = GeneratedColumn<int>(
      'reviewed_at_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
      'day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dailyMeta = const VerificationMeta('daily');
  @override
  late final GeneratedColumn<bool> daily = GeneratedColumn<bool>(
      'daily', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("daily" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns =>
      [id, cardId, collegeId, rang, drillLevel, reviewedAtMs, day, daily];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'review_log';
  @override
  VerificationContext validateIntegrity(Insertable<ReviewLogRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(_cardIdMeta,
          cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta));
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('college_id')) {
      context.handle(_collegeIdMeta,
          collegeId.isAcceptableOrUnknown(data['college_id']!, _collegeIdMeta));
    } else if (isInserting) {
      context.missing(_collegeIdMeta);
    }
    if (data.containsKey('rang')) {
      context.handle(
          _rangMeta, rang.isAcceptableOrUnknown(data['rang']!, _rangMeta));
    } else if (isInserting) {
      context.missing(_rangMeta);
    }
    if (data.containsKey('drill_level')) {
      context.handle(
          _drillLevelMeta,
          drillLevel.isAcceptableOrUnknown(
              data['drill_level']!, _drillLevelMeta));
    } else if (isInserting) {
      context.missing(_drillLevelMeta);
    }
    if (data.containsKey('reviewed_at_ms')) {
      context.handle(
          _reviewedAtMsMeta,
          reviewedAtMs.isAcceptableOrUnknown(
              data['reviewed_at_ms']!, _reviewedAtMsMeta));
    } else if (isInserting) {
      context.missing(_reviewedAtMsMeta);
    }
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('daily')) {
      context.handle(
          _dailyMeta, daily.isAcceptableOrUnknown(data['daily']!, _dailyMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReviewLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReviewLogRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      cardId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}card_id'])!,
      collegeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}college_id'])!,
      rang: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rang'])!,
      drillLevel: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}drill_level'])!,
      reviewedAtMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}reviewed_at_ms'])!,
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day'])!,
      daily: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}daily'])!,
    );
  }

  @override
  $ReviewLogTable createAlias(String alias) {
    return $ReviewLogTable(attachedDatabase, alias);
  }
}

class ReviewLogRow extends DataClass implements Insertable<ReviewLogRow> {
  final int id;
  final String cardId;
  final String collegeId;
  final String rang;

  /// Même vocabulaire que `flash_cards.drillLevel` : `a_revoir` | `bien` | `maitrise`.
  final String drillLevel;
  final int reviewedAtMs;

  /// Jour local de la révision (`epochDayOf`), pour les regroupements par jour.
  final int day;

  /// Verdict de la session du jour (son bilan) ; `false` : autre révision
  /// (collège, item, recherche, refaire les erreurs), comptée dans la semaine
  /// de Progression seulement (story 8.8).
  final bool daily;
  const ReviewLogRow(
      {required this.id,
      required this.cardId,
      required this.collegeId,
      required this.rang,
      required this.drillLevel,
      required this.reviewedAtMs,
      required this.day,
      required this.daily});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<String>(cardId);
    map['college_id'] = Variable<String>(collegeId);
    map['rang'] = Variable<String>(rang);
    map['drill_level'] = Variable<String>(drillLevel);
    map['reviewed_at_ms'] = Variable<int>(reviewedAtMs);
    map['day'] = Variable<int>(day);
    map['daily'] = Variable<bool>(daily);
    return map;
  }

  ReviewLogCompanion toCompanion(bool nullToAbsent) {
    return ReviewLogCompanion(
      id: Value(id),
      cardId: Value(cardId),
      collegeId: Value(collegeId),
      rang: Value(rang),
      drillLevel: Value(drillLevel),
      reviewedAtMs: Value(reviewedAtMs),
      day: Value(day),
      daily: Value(daily),
    );
  }

  factory ReviewLogRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReviewLogRow(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<String>(json['cardId']),
      collegeId: serializer.fromJson<String>(json['collegeId']),
      rang: serializer.fromJson<String>(json['rang']),
      drillLevel: serializer.fromJson<String>(json['drillLevel']),
      reviewedAtMs: serializer.fromJson<int>(json['reviewedAtMs']),
      day: serializer.fromJson<int>(json['day']),
      daily: serializer.fromJson<bool>(json['daily']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<String>(cardId),
      'collegeId': serializer.toJson<String>(collegeId),
      'rang': serializer.toJson<String>(rang),
      'drillLevel': serializer.toJson<String>(drillLevel),
      'reviewedAtMs': serializer.toJson<int>(reviewedAtMs),
      'day': serializer.toJson<int>(day),
      'daily': serializer.toJson<bool>(daily),
    };
  }

  ReviewLogRow copyWith(
          {int? id,
          String? cardId,
          String? collegeId,
          String? rang,
          String? drillLevel,
          int? reviewedAtMs,
          int? day,
          bool? daily}) =>
      ReviewLogRow(
        id: id ?? this.id,
        cardId: cardId ?? this.cardId,
        collegeId: collegeId ?? this.collegeId,
        rang: rang ?? this.rang,
        drillLevel: drillLevel ?? this.drillLevel,
        reviewedAtMs: reviewedAtMs ?? this.reviewedAtMs,
        day: day ?? this.day,
        daily: daily ?? this.daily,
      );
  ReviewLogRow copyWithCompanion(ReviewLogCompanion data) {
    return ReviewLogRow(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      collegeId: data.collegeId.present ? data.collegeId.value : this.collegeId,
      rang: data.rang.present ? data.rang.value : this.rang,
      drillLevel:
          data.drillLevel.present ? data.drillLevel.value : this.drillLevel,
      reviewedAtMs: data.reviewedAtMs.present
          ? data.reviewedAtMs.value
          : this.reviewedAtMs,
      day: data.day.present ? data.day.value : this.day,
      daily: data.daily.present ? data.daily.value : this.daily,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogRow(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('collegeId: $collegeId, ')
          ..write('rang: $rang, ')
          ..write('drillLevel: $drillLevel, ')
          ..write('reviewedAtMs: $reviewedAtMs, ')
          ..write('day: $day, ')
          ..write('daily: $daily')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, cardId, collegeId, rang, drillLevel, reviewedAtMs, day, daily);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReviewLogRow &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.collegeId == this.collegeId &&
          other.rang == this.rang &&
          other.drillLevel == this.drillLevel &&
          other.reviewedAtMs == this.reviewedAtMs &&
          other.day == this.day &&
          other.daily == this.daily);
}

class ReviewLogCompanion extends UpdateCompanion<ReviewLogRow> {
  final Value<int> id;
  final Value<String> cardId;
  final Value<String> collegeId;
  final Value<String> rang;
  final Value<String> drillLevel;
  final Value<int> reviewedAtMs;
  final Value<int> day;
  final Value<bool> daily;
  const ReviewLogCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.collegeId = const Value.absent(),
    this.rang = const Value.absent(),
    this.drillLevel = const Value.absent(),
    this.reviewedAtMs = const Value.absent(),
    this.day = const Value.absent(),
    this.daily = const Value.absent(),
  });
  ReviewLogCompanion.insert({
    this.id = const Value.absent(),
    required String cardId,
    required String collegeId,
    required String rang,
    required String drillLevel,
    required int reviewedAtMs,
    required int day,
    this.daily = const Value.absent(),
  })  : cardId = Value(cardId),
        collegeId = Value(collegeId),
        rang = Value(rang),
        drillLevel = Value(drillLevel),
        reviewedAtMs = Value(reviewedAtMs),
        day = Value(day);
  static Insertable<ReviewLogRow> custom({
    Expression<int>? id,
    Expression<String>? cardId,
    Expression<String>? collegeId,
    Expression<String>? rang,
    Expression<String>? drillLevel,
    Expression<int>? reviewedAtMs,
    Expression<int>? day,
    Expression<bool>? daily,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (collegeId != null) 'college_id': collegeId,
      if (rang != null) 'rang': rang,
      if (drillLevel != null) 'drill_level': drillLevel,
      if (reviewedAtMs != null) 'reviewed_at_ms': reviewedAtMs,
      if (day != null) 'day': day,
      if (daily != null) 'daily': daily,
    });
  }

  ReviewLogCompanion copyWith(
      {Value<int>? id,
      Value<String>? cardId,
      Value<String>? collegeId,
      Value<String>? rang,
      Value<String>? drillLevel,
      Value<int>? reviewedAtMs,
      Value<int>? day,
      Value<bool>? daily}) {
    return ReviewLogCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      collegeId: collegeId ?? this.collegeId,
      rang: rang ?? this.rang,
      drillLevel: drillLevel ?? this.drillLevel,
      reviewedAtMs: reviewedAtMs ?? this.reviewedAtMs,
      day: day ?? this.day,
      daily: daily ?? this.daily,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (collegeId.present) {
      map['college_id'] = Variable<String>(collegeId.value);
    }
    if (rang.present) {
      map['rang'] = Variable<String>(rang.value);
    }
    if (drillLevel.present) {
      map['drill_level'] = Variable<String>(drillLevel.value);
    }
    if (reviewedAtMs.present) {
      map['reviewed_at_ms'] = Variable<int>(reviewedAtMs.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (daily.present) {
      map['daily'] = Variable<bool>(daily.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReviewLogCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('collegeId: $collegeId, ')
          ..write('rang: $rang, ')
          ..write('drillLevel: $drillLevel, ')
          ..write('reviewedAtMs: $reviewedAtMs, ')
          ..write('day: $day, ')
          ..write('daily: $daily')
          ..write(')'))
        .toString();
  }
}

class $UserCollegesTable extends UserColleges
    with TableInfo<$UserCollegesTable, UserCollegeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserCollegesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _refIdMeta = const VerificationMeta('refId');
  @override
  late final GeneratedColumn<int> refId = GeneratedColumn<int>(
      'ref_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _collegeIdMeta =
      const VerificationMeta('collegeId');
  @override
  late final GeneratedColumn<String> collegeId = GeneratedColumn<String>(
      'college_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cardCountAMeta =
      const VerificationMeta('cardCountA');
  @override
  late final GeneratedColumn<int> cardCountA = GeneratedColumn<int>(
      'card_count_a', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _cardCountBMeta =
      const VerificationMeta('cardCountB');
  @override
  late final GeneratedColumn<int> cardCountB = GeneratedColumn<int>(
      'card_count_b', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _cardCountCMeta =
      const VerificationMeta('cardCountC');
  @override
  late final GeneratedColumn<int> cardCountC = GeneratedColumn<int>(
      'card_count_c', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _pdfVersionMeta =
      const VerificationMeta('pdfVersion');
  @override
  late final GeneratedColumn<String> pdfVersion = GeneratedColumn<String>(
      'pdf_version', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pdfSizeMeta =
      const VerificationMeta('pdfSize');
  @override
  late final GeneratedColumn<int> pdfSize = GeneratedColumn<int>(
      'pdf_size', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        refId,
        collegeId,
        status,
        cardCountA,
        cardCountB,
        cardCountC,
        pdfVersion,
        pdfSize
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_colleges';
  @override
  VerificationContext validateIntegrity(Insertable<UserCollegeRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ref_id')) {
      context.handle(
          _refIdMeta, refId.isAcceptableOrUnknown(data['ref_id']!, _refIdMeta));
    }
    if (data.containsKey('college_id')) {
      context.handle(_collegeIdMeta,
          collegeId.isAcceptableOrUnknown(data['college_id']!, _collegeIdMeta));
    } else if (isInserting) {
      context.missing(_collegeIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('card_count_a')) {
      context.handle(
          _cardCountAMeta,
          cardCountA.isAcceptableOrUnknown(
              data['card_count_a']!, _cardCountAMeta));
    } else if (isInserting) {
      context.missing(_cardCountAMeta);
    }
    if (data.containsKey('card_count_b')) {
      context.handle(
          _cardCountBMeta,
          cardCountB.isAcceptableOrUnknown(
              data['card_count_b']!, _cardCountBMeta));
    } else if (isInserting) {
      context.missing(_cardCountBMeta);
    }
    if (data.containsKey('card_count_c')) {
      context.handle(
          _cardCountCMeta,
          cardCountC.isAcceptableOrUnknown(
              data['card_count_c']!, _cardCountCMeta));
    } else if (isInserting) {
      context.missing(_cardCountCMeta);
    }
    if (data.containsKey('pdf_version')) {
      context.handle(
          _pdfVersionMeta,
          pdfVersion.isAcceptableOrUnknown(
              data['pdf_version']!, _pdfVersionMeta));
    }
    if (data.containsKey('pdf_size')) {
      context.handle(_pdfSizeMeta,
          pdfSize.isAcceptableOrUnknown(data['pdf_size']!, _pdfSizeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {refId};
  @override
  UserCollegeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserCollegeRow(
      refId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ref_id'])!,
      collegeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}college_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      cardCountA: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}card_count_a'])!,
      cardCountB: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}card_count_b'])!,
      cardCountC: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}card_count_c'])!,
      pdfVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pdf_version']),
      pdfSize: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}pdf_size']),
    );
  }

  @override
  $UserCollegesTable createAlias(String alias) {
    return $UserCollegesTable(attachedDatabase, alias);
  }
}

class UserCollegeRow extends DataClass implements Insertable<UserCollegeRow> {
  final int refId;
  final String collegeId;
  final String status;
  final int cardCountA;
  final int cardCountB;
  final int cardCountC;

  /// PDF en service côté serveur (id du dernier job publié) et sa taille (partie B).
  final String? pdfVersion;
  final int? pdfSize;
  const UserCollegeRow(
      {required this.refId,
      required this.collegeId,
      required this.status,
      required this.cardCountA,
      required this.cardCountB,
      required this.cardCountC,
      this.pdfVersion,
      this.pdfSize});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ref_id'] = Variable<int>(refId);
    map['college_id'] = Variable<String>(collegeId);
    map['status'] = Variable<String>(status);
    map['card_count_a'] = Variable<int>(cardCountA);
    map['card_count_b'] = Variable<int>(cardCountB);
    map['card_count_c'] = Variable<int>(cardCountC);
    if (!nullToAbsent || pdfVersion != null) {
      map['pdf_version'] = Variable<String>(pdfVersion);
    }
    if (!nullToAbsent || pdfSize != null) {
      map['pdf_size'] = Variable<int>(pdfSize);
    }
    return map;
  }

  UserCollegesCompanion toCompanion(bool nullToAbsent) {
    return UserCollegesCompanion(
      refId: Value(refId),
      collegeId: Value(collegeId),
      status: Value(status),
      cardCountA: Value(cardCountA),
      cardCountB: Value(cardCountB),
      cardCountC: Value(cardCountC),
      pdfVersion: pdfVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfVersion),
      pdfSize: pdfSize == null && nullToAbsent
          ? const Value.absent()
          : Value(pdfSize),
    );
  }

  factory UserCollegeRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserCollegeRow(
      refId: serializer.fromJson<int>(json['refId']),
      collegeId: serializer.fromJson<String>(json['collegeId']),
      status: serializer.fromJson<String>(json['status']),
      cardCountA: serializer.fromJson<int>(json['cardCountA']),
      cardCountB: serializer.fromJson<int>(json['cardCountB']),
      cardCountC: serializer.fromJson<int>(json['cardCountC']),
      pdfVersion: serializer.fromJson<String?>(json['pdfVersion']),
      pdfSize: serializer.fromJson<int?>(json['pdfSize']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'refId': serializer.toJson<int>(refId),
      'collegeId': serializer.toJson<String>(collegeId),
      'status': serializer.toJson<String>(status),
      'cardCountA': serializer.toJson<int>(cardCountA),
      'cardCountB': serializer.toJson<int>(cardCountB),
      'cardCountC': serializer.toJson<int>(cardCountC),
      'pdfVersion': serializer.toJson<String?>(pdfVersion),
      'pdfSize': serializer.toJson<int?>(pdfSize),
    };
  }

  UserCollegeRow copyWith(
          {int? refId,
          String? collegeId,
          String? status,
          int? cardCountA,
          int? cardCountB,
          int? cardCountC,
          Value<String?> pdfVersion = const Value.absent(),
          Value<int?> pdfSize = const Value.absent()}) =>
      UserCollegeRow(
        refId: refId ?? this.refId,
        collegeId: collegeId ?? this.collegeId,
        status: status ?? this.status,
        cardCountA: cardCountA ?? this.cardCountA,
        cardCountB: cardCountB ?? this.cardCountB,
        cardCountC: cardCountC ?? this.cardCountC,
        pdfVersion: pdfVersion.present ? pdfVersion.value : this.pdfVersion,
        pdfSize: pdfSize.present ? pdfSize.value : this.pdfSize,
      );
  UserCollegeRow copyWithCompanion(UserCollegesCompanion data) {
    return UserCollegeRow(
      refId: data.refId.present ? data.refId.value : this.refId,
      collegeId: data.collegeId.present ? data.collegeId.value : this.collegeId,
      status: data.status.present ? data.status.value : this.status,
      cardCountA:
          data.cardCountA.present ? data.cardCountA.value : this.cardCountA,
      cardCountB:
          data.cardCountB.present ? data.cardCountB.value : this.cardCountB,
      cardCountC:
          data.cardCountC.present ? data.cardCountC.value : this.cardCountC,
      pdfVersion:
          data.pdfVersion.present ? data.pdfVersion.value : this.pdfVersion,
      pdfSize: data.pdfSize.present ? data.pdfSize.value : this.pdfSize,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserCollegeRow(')
          ..write('refId: $refId, ')
          ..write('collegeId: $collegeId, ')
          ..write('status: $status, ')
          ..write('cardCountA: $cardCountA, ')
          ..write('cardCountB: $cardCountB, ')
          ..write('cardCountC: $cardCountC, ')
          ..write('pdfVersion: $pdfVersion, ')
          ..write('pdfSize: $pdfSize')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(refId, collegeId, status, cardCountA,
      cardCountB, cardCountC, pdfVersion, pdfSize);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserCollegeRow &&
          other.refId == this.refId &&
          other.collegeId == this.collegeId &&
          other.status == this.status &&
          other.cardCountA == this.cardCountA &&
          other.cardCountB == this.cardCountB &&
          other.cardCountC == this.cardCountC &&
          other.pdfVersion == this.pdfVersion &&
          other.pdfSize == this.pdfSize);
}

class UserCollegesCompanion extends UpdateCompanion<UserCollegeRow> {
  final Value<int> refId;
  final Value<String> collegeId;
  final Value<String> status;
  final Value<int> cardCountA;
  final Value<int> cardCountB;
  final Value<int> cardCountC;
  final Value<String?> pdfVersion;
  final Value<int?> pdfSize;
  const UserCollegesCompanion({
    this.refId = const Value.absent(),
    this.collegeId = const Value.absent(),
    this.status = const Value.absent(),
    this.cardCountA = const Value.absent(),
    this.cardCountB = const Value.absent(),
    this.cardCountC = const Value.absent(),
    this.pdfVersion = const Value.absent(),
    this.pdfSize = const Value.absent(),
  });
  UserCollegesCompanion.insert({
    this.refId = const Value.absent(),
    required String collegeId,
    required String status,
    required int cardCountA,
    required int cardCountB,
    required int cardCountC,
    this.pdfVersion = const Value.absent(),
    this.pdfSize = const Value.absent(),
  })  : collegeId = Value(collegeId),
        status = Value(status),
        cardCountA = Value(cardCountA),
        cardCountB = Value(cardCountB),
        cardCountC = Value(cardCountC);
  static Insertable<UserCollegeRow> custom({
    Expression<int>? refId,
    Expression<String>? collegeId,
    Expression<String>? status,
    Expression<int>? cardCountA,
    Expression<int>? cardCountB,
    Expression<int>? cardCountC,
    Expression<String>? pdfVersion,
    Expression<int>? pdfSize,
  }) {
    return RawValuesInsertable({
      if (refId != null) 'ref_id': refId,
      if (collegeId != null) 'college_id': collegeId,
      if (status != null) 'status': status,
      if (cardCountA != null) 'card_count_a': cardCountA,
      if (cardCountB != null) 'card_count_b': cardCountB,
      if (cardCountC != null) 'card_count_c': cardCountC,
      if (pdfVersion != null) 'pdf_version': pdfVersion,
      if (pdfSize != null) 'pdf_size': pdfSize,
    });
  }

  UserCollegesCompanion copyWith(
      {Value<int>? refId,
      Value<String>? collegeId,
      Value<String>? status,
      Value<int>? cardCountA,
      Value<int>? cardCountB,
      Value<int>? cardCountC,
      Value<String?>? pdfVersion,
      Value<int?>? pdfSize}) {
    return UserCollegesCompanion(
      refId: refId ?? this.refId,
      collegeId: collegeId ?? this.collegeId,
      status: status ?? this.status,
      cardCountA: cardCountA ?? this.cardCountA,
      cardCountB: cardCountB ?? this.cardCountB,
      cardCountC: cardCountC ?? this.cardCountC,
      pdfVersion: pdfVersion ?? this.pdfVersion,
      pdfSize: pdfSize ?? this.pdfSize,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (refId.present) {
      map['ref_id'] = Variable<int>(refId.value);
    }
    if (collegeId.present) {
      map['college_id'] = Variable<String>(collegeId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (cardCountA.present) {
      map['card_count_a'] = Variable<int>(cardCountA.value);
    }
    if (cardCountB.present) {
      map['card_count_b'] = Variable<int>(cardCountB.value);
    }
    if (cardCountC.present) {
      map['card_count_c'] = Variable<int>(cardCountC.value);
    }
    if (pdfVersion.present) {
      map['pdf_version'] = Variable<String>(pdfVersion.value);
    }
    if (pdfSize.present) {
      map['pdf_size'] = Variable<int>(pdfSize.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserCollegesCompanion(')
          ..write('refId: $refId, ')
          ..write('collegeId: $collegeId, ')
          ..write('status: $status, ')
          ..write('cardCountA: $cardCountA, ')
          ..write('cardCountB: $cardCountB, ')
          ..write('cardCountC: $cardCountC, ')
          ..write('pdfVersion: $pdfVersion, ')
          ..write('pdfSize: $pdfSize')
          ..write(')'))
        .toString();
  }
}

class $QuietDaysTable extends QuietDays
    with TableInfo<$QuietDaysTable, QuietDayRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuietDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
      'day', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [day];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiet_days';
  @override
  VerificationContext validateIntegrity(Insertable<QuietDayRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
          _dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  QuietDayRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuietDayRow(
      day: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day'])!,
    );
  }

  @override
  $QuietDaysTable createAlias(String alias) {
    return $QuietDaysTable(attachedDatabase, alias);
  }
}

class QuietDayRow extends DataClass implements Insertable<QuietDayRow> {
  /// Jour local (`epochDayOf`).
  final int day;
  const QuietDayRow({required this.day});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<int>(day);
    return map;
  }

  QuietDaysCompanion toCompanion(bool nullToAbsent) {
    return QuietDaysCompanion(
      day: Value(day),
    );
  }

  factory QuietDayRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuietDayRow(
      day: serializer.fromJson<int>(json['day']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<int>(day),
    };
  }

  QuietDayRow copyWith({int? day}) => QuietDayRow(
        day: day ?? this.day,
      );
  QuietDayRow copyWithCompanion(QuietDaysCompanion data) {
    return QuietDayRow(
      day: data.day.present ? data.day.value : this.day,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuietDayRow(')
          ..write('day: $day')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => day.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is QuietDayRow && other.day == this.day);
}

class QuietDaysCompanion extends UpdateCompanion<QuietDayRow> {
  final Value<int> day;
  const QuietDaysCompanion({
    this.day = const Value.absent(),
  });
  QuietDaysCompanion.insert({
    this.day = const Value.absent(),
  });
  static Insertable<QuietDayRow> custom({
    Expression<int>? day,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
    });
  }

  QuietDaysCompanion copyWith({Value<int>? day}) {
    return QuietDaysCompanion(
      day: day ?? this.day,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuietDaysCompanion(')
          ..write('day: $day')
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
  late final $PendingUploadsTable pendingUploads = $PendingUploadsTable(this);
  late final $DailySessionsTable dailySessions = $DailySessionsTable(this);
  late final $ReviewLogTable reviewLog = $ReviewLogTable(this);
  late final $UserCollegesTable userColleges = $UserCollegesTable(this);
  late final $QuietDaysTable quietDays = $QuietDaysTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        collegeImports,
        items,
        flashCards,
        planningConfigs,
        planningSessions,
        pendingUploads,
        dailySessions,
        reviewLog,
        userColleges,
        quietDays
      ];
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
  Value<int?> startPage,
  Value<int?> endPage,
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
  Value<int?> startPage,
  Value<int?> endPage,
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

  ColumnFilters<int> get startPage => $composableBuilder(
      column: $table.startPage, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endPage => $composableBuilder(
      column: $table.endPage, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<int> get startPage => $composableBuilder(
      column: $table.startPage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endPage => $composableBuilder(
      column: $table.endPage, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<int> get startPage =>
      $composableBuilder(column: $table.startPage, builder: (column) => column);

  GeneratedColumn<int> get endPage =>
      $composableBuilder(column: $table.endPage, builder: (column) => column);
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
            Value<int?> startPage = const Value.absent(),
            Value<int?> endPage = const Value.absent(),
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
            startPage: startPage,
            endPage: endPage,
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
            Value<int?> startPage = const Value.absent(),
            Value<int?> endPage = const Value.absent(),
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
            startPage: startPage,
            endPage: endPage,
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
typedef $$PendingUploadsTableCreateCompanionBuilder = PendingUploadsCompanion
    Function({
  required String uploadId,
  required int refId,
  required String filePath,
  required int sizeBytes,
  required int partSize,
  required int partsTotal,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$PendingUploadsTableUpdateCompanionBuilder = PendingUploadsCompanion
    Function({
  Value<String> uploadId,
  Value<int> refId,
  Value<String> filePath,
  Value<int> sizeBytes,
  Value<int> partSize,
  Value<int> partsTotal,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$PendingUploadsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uploadId => $composableBuilder(
      column: $table.uploadId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get refId => $composableBuilder(
      column: $table.refId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get partSize => $composableBuilder(
      column: $table.partSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get partsTotal => $composableBuilder(
      column: $table.partsTotal, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$PendingUploadsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uploadId => $composableBuilder(
      column: $table.uploadId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get refId => $composableBuilder(
      column: $table.refId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get partSize => $composableBuilder(
      column: $table.partSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get partsTotal => $composableBuilder(
      column: $table.partsTotal, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$PendingUploadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingUploadsTable> {
  $$PendingUploadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uploadId =>
      $composableBuilder(column: $table.uploadId, builder: (column) => column);

  GeneratedColumn<int> get refId =>
      $composableBuilder(column: $table.refId, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get partSize =>
      $composableBuilder(column: $table.partSize, builder: (column) => column);

  GeneratedColumn<int> get partsTotal => $composableBuilder(
      column: $table.partsTotal, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingUploadsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingUploadsTable,
    PendingUpload,
    $$PendingUploadsTableFilterComposer,
    $$PendingUploadsTableOrderingComposer,
    $$PendingUploadsTableAnnotationComposer,
    $$PendingUploadsTableCreateCompanionBuilder,
    $$PendingUploadsTableUpdateCompanionBuilder,
    (
      PendingUpload,
      BaseReferences<_$AppDatabase, $PendingUploadsTable, PendingUpload>
    ),
    PendingUpload,
    PrefetchHooks Function()> {
  $$PendingUploadsTableTableManager(
      _$AppDatabase db, $PendingUploadsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingUploadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingUploadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingUploadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> uploadId = const Value.absent(),
            Value<int> refId = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<int> sizeBytes = const Value.absent(),
            Value<int> partSize = const Value.absent(),
            Value<int> partsTotal = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingUploadsCompanion(
            uploadId: uploadId,
            refId: refId,
            filePath: filePath,
            sizeBytes: sizeBytes,
            partSize: partSize,
            partsTotal: partsTotal,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String uploadId,
            required int refId,
            required String filePath,
            required int sizeBytes,
            required int partSize,
            required int partsTotal,
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PendingUploadsCompanion.insert(
            uploadId: uploadId,
            refId: refId,
            filePath: filePath,
            sizeBytes: sizeBytes,
            partSize: partSize,
            partsTotal: partsTotal,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingUploadsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PendingUploadsTable,
    PendingUpload,
    $$PendingUploadsTableFilterComposer,
    $$PendingUploadsTableOrderingComposer,
    $$PendingUploadsTableAnnotationComposer,
    $$PendingUploadsTableCreateCompanionBuilder,
    $$PendingUploadsTableUpdateCompanionBuilder,
    (
      PendingUpload,
      BaseReferences<_$AppDatabase, $PendingUploadsTable, PendingUpload>
    ),
    PendingUpload,
    PrefetchHooks Function()>;
typedef $$DailySessionsTableCreateCompanionBuilder = DailySessionsCompanion
    Function({
  Value<int> day,
  required String queueJson,
  Value<int> position,
  Value<String?> settingsJson,
  Value<int?> startedAtMs,
  Value<int?> completedAtMs,
});
typedef $$DailySessionsTableUpdateCompanionBuilder = DailySessionsCompanion
    Function({
  Value<int> day,
  Value<String> queueJson,
  Value<int> position,
  Value<String?> settingsJson,
  Value<int?> startedAtMs,
  Value<int?> completedAtMs,
});

class $$DailySessionsTableFilterComposer
    extends Composer<_$AppDatabase, $DailySessionsTable> {
  $$DailySessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get queueJson => $composableBuilder(
      column: $table.queueJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get settingsJson => $composableBuilder(
      column: $table.settingsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAtMs => $composableBuilder(
      column: $table.startedAtMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completedAtMs => $composableBuilder(
      column: $table.completedAtMs, builder: (column) => ColumnFilters(column));
}

class $$DailySessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailySessionsTable> {
  $$DailySessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get queueJson => $composableBuilder(
      column: $table.queueJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get settingsJson => $composableBuilder(
      column: $table.settingsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAtMs => $composableBuilder(
      column: $table.startedAtMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completedAtMs => $composableBuilder(
      column: $table.completedAtMs,
      builder: (column) => ColumnOrderings(column));
}

class $$DailySessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailySessionsTable> {
  $$DailySessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get queueJson =>
      $composableBuilder(column: $table.queueJson, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get settingsJson => $composableBuilder(
      column: $table.settingsJson, builder: (column) => column);

  GeneratedColumn<int> get startedAtMs => $composableBuilder(
      column: $table.startedAtMs, builder: (column) => column);

  GeneratedColumn<int> get completedAtMs => $composableBuilder(
      column: $table.completedAtMs, builder: (column) => column);
}

class $$DailySessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DailySessionsTable,
    DailySessionRow,
    $$DailySessionsTableFilterComposer,
    $$DailySessionsTableOrderingComposer,
    $$DailySessionsTableAnnotationComposer,
    $$DailySessionsTableCreateCompanionBuilder,
    $$DailySessionsTableUpdateCompanionBuilder,
    (
      DailySessionRow,
      BaseReferences<_$AppDatabase, $DailySessionsTable, DailySessionRow>
    ),
    DailySessionRow,
    PrefetchHooks Function()> {
  $$DailySessionsTableTableManager(_$AppDatabase db, $DailySessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailySessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailySessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailySessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> day = const Value.absent(),
            Value<String> queueJson = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<String?> settingsJson = const Value.absent(),
            Value<int?> startedAtMs = const Value.absent(),
            Value<int?> completedAtMs = const Value.absent(),
          }) =>
              DailySessionsCompanion(
            day: day,
            queueJson: queueJson,
            position: position,
            settingsJson: settingsJson,
            startedAtMs: startedAtMs,
            completedAtMs: completedAtMs,
          ),
          createCompanionCallback: ({
            Value<int> day = const Value.absent(),
            required String queueJson,
            Value<int> position = const Value.absent(),
            Value<String?> settingsJson = const Value.absent(),
            Value<int?> startedAtMs = const Value.absent(),
            Value<int?> completedAtMs = const Value.absent(),
          }) =>
              DailySessionsCompanion.insert(
            day: day,
            queueJson: queueJson,
            position: position,
            settingsJson: settingsJson,
            startedAtMs: startedAtMs,
            completedAtMs: completedAtMs,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DailySessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DailySessionsTable,
    DailySessionRow,
    $$DailySessionsTableFilterComposer,
    $$DailySessionsTableOrderingComposer,
    $$DailySessionsTableAnnotationComposer,
    $$DailySessionsTableCreateCompanionBuilder,
    $$DailySessionsTableUpdateCompanionBuilder,
    (
      DailySessionRow,
      BaseReferences<_$AppDatabase, $DailySessionsTable, DailySessionRow>
    ),
    DailySessionRow,
    PrefetchHooks Function()>;
typedef $$ReviewLogTableCreateCompanionBuilder = ReviewLogCompanion Function({
  Value<int> id,
  required String cardId,
  required String collegeId,
  required String rang,
  required String drillLevel,
  required int reviewedAtMs,
  required int day,
  Value<bool> daily,
});
typedef $$ReviewLogTableUpdateCompanionBuilder = ReviewLogCompanion Function({
  Value<int> id,
  Value<String> cardId,
  Value<String> collegeId,
  Value<String> rang,
  Value<String> drillLevel,
  Value<int> reviewedAtMs,
  Value<int> day,
  Value<bool> daily,
});

class $$ReviewLogTableFilterComposer
    extends Composer<_$AppDatabase, $ReviewLogTable> {
  $$ReviewLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cardId => $composableBuilder(
      column: $table.cardId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collegeId => $composableBuilder(
      column: $table.collegeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rang => $composableBuilder(
      column: $table.rang, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get drillLevel => $composableBuilder(
      column: $table.drillLevel, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reviewedAtMs => $composableBuilder(
      column: $table.reviewedAtMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get daily => $composableBuilder(
      column: $table.daily, builder: (column) => ColumnFilters(column));
}

class $$ReviewLogTableOrderingComposer
    extends Composer<_$AppDatabase, $ReviewLogTable> {
  $$ReviewLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cardId => $composableBuilder(
      column: $table.cardId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collegeId => $composableBuilder(
      column: $table.collegeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rang => $composableBuilder(
      column: $table.rang, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get drillLevel => $composableBuilder(
      column: $table.drillLevel, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reviewedAtMs => $composableBuilder(
      column: $table.reviewedAtMs,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get daily => $composableBuilder(
      column: $table.daily, builder: (column) => ColumnOrderings(column));
}

class $$ReviewLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReviewLogTable> {
  $$ReviewLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get cardId =>
      $composableBuilder(column: $table.cardId, builder: (column) => column);

  GeneratedColumn<String> get collegeId =>
      $composableBuilder(column: $table.collegeId, builder: (column) => column);

  GeneratedColumn<String> get rang =>
      $composableBuilder(column: $table.rang, builder: (column) => column);

  GeneratedColumn<String> get drillLevel => $composableBuilder(
      column: $table.drillLevel, builder: (column) => column);

  GeneratedColumn<int> get reviewedAtMs => $composableBuilder(
      column: $table.reviewedAtMs, builder: (column) => column);

  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<bool> get daily =>
      $composableBuilder(column: $table.daily, builder: (column) => column);
}

class $$ReviewLogTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReviewLogTable,
    ReviewLogRow,
    $$ReviewLogTableFilterComposer,
    $$ReviewLogTableOrderingComposer,
    $$ReviewLogTableAnnotationComposer,
    $$ReviewLogTableCreateCompanionBuilder,
    $$ReviewLogTableUpdateCompanionBuilder,
    (
      ReviewLogRow,
      BaseReferences<_$AppDatabase, $ReviewLogTable, ReviewLogRow>
    ),
    ReviewLogRow,
    PrefetchHooks Function()> {
  $$ReviewLogTableTableManager(_$AppDatabase db, $ReviewLogTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReviewLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReviewLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReviewLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> cardId = const Value.absent(),
            Value<String> collegeId = const Value.absent(),
            Value<String> rang = const Value.absent(),
            Value<String> drillLevel = const Value.absent(),
            Value<int> reviewedAtMs = const Value.absent(),
            Value<int> day = const Value.absent(),
            Value<bool> daily = const Value.absent(),
          }) =>
              ReviewLogCompanion(
            id: id,
            cardId: cardId,
            collegeId: collegeId,
            rang: rang,
            drillLevel: drillLevel,
            reviewedAtMs: reviewedAtMs,
            day: day,
            daily: daily,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String cardId,
            required String collegeId,
            required String rang,
            required String drillLevel,
            required int reviewedAtMs,
            required int day,
            Value<bool> daily = const Value.absent(),
          }) =>
              ReviewLogCompanion.insert(
            id: id,
            cardId: cardId,
            collegeId: collegeId,
            rang: rang,
            drillLevel: drillLevel,
            reviewedAtMs: reviewedAtMs,
            day: day,
            daily: daily,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReviewLogTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReviewLogTable,
    ReviewLogRow,
    $$ReviewLogTableFilterComposer,
    $$ReviewLogTableOrderingComposer,
    $$ReviewLogTableAnnotationComposer,
    $$ReviewLogTableCreateCompanionBuilder,
    $$ReviewLogTableUpdateCompanionBuilder,
    (
      ReviewLogRow,
      BaseReferences<_$AppDatabase, $ReviewLogTable, ReviewLogRow>
    ),
    ReviewLogRow,
    PrefetchHooks Function()>;
typedef $$UserCollegesTableCreateCompanionBuilder = UserCollegesCompanion
    Function({
  Value<int> refId,
  required String collegeId,
  required String status,
  required int cardCountA,
  required int cardCountB,
  required int cardCountC,
  Value<String?> pdfVersion,
  Value<int?> pdfSize,
});
typedef $$UserCollegesTableUpdateCompanionBuilder = UserCollegesCompanion
    Function({
  Value<int> refId,
  Value<String> collegeId,
  Value<String> status,
  Value<int> cardCountA,
  Value<int> cardCountB,
  Value<int> cardCountC,
  Value<String?> pdfVersion,
  Value<int?> pdfSize,
});

class $$UserCollegesTableFilterComposer
    extends Composer<_$AppDatabase, $UserCollegesTable> {
  $$UserCollegesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get refId => $composableBuilder(
      column: $table.refId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get collegeId => $composableBuilder(
      column: $table.collegeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cardCountA => $composableBuilder(
      column: $table.cardCountA, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cardCountB => $composableBuilder(
      column: $table.cardCountB, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cardCountC => $composableBuilder(
      column: $table.cardCountC, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pdfVersion => $composableBuilder(
      column: $table.pdfVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pdfSize => $composableBuilder(
      column: $table.pdfSize, builder: (column) => ColumnFilters(column));
}

class $$UserCollegesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserCollegesTable> {
  $$UserCollegesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get refId => $composableBuilder(
      column: $table.refId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get collegeId => $composableBuilder(
      column: $table.collegeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cardCountA => $composableBuilder(
      column: $table.cardCountA, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cardCountB => $composableBuilder(
      column: $table.cardCountB, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cardCountC => $composableBuilder(
      column: $table.cardCountC, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pdfVersion => $composableBuilder(
      column: $table.pdfVersion, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pdfSize => $composableBuilder(
      column: $table.pdfSize, builder: (column) => ColumnOrderings(column));
}

class $$UserCollegesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserCollegesTable> {
  $$UserCollegesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get refId =>
      $composableBuilder(column: $table.refId, builder: (column) => column);

  GeneratedColumn<String> get collegeId =>
      $composableBuilder(column: $table.collegeId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get cardCountA => $composableBuilder(
      column: $table.cardCountA, builder: (column) => column);

  GeneratedColumn<int> get cardCountB => $composableBuilder(
      column: $table.cardCountB, builder: (column) => column);

  GeneratedColumn<int> get cardCountC => $composableBuilder(
      column: $table.cardCountC, builder: (column) => column);

  GeneratedColumn<String> get pdfVersion => $composableBuilder(
      column: $table.pdfVersion, builder: (column) => column);

  GeneratedColumn<int> get pdfSize =>
      $composableBuilder(column: $table.pdfSize, builder: (column) => column);
}

class $$UserCollegesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserCollegesTable,
    UserCollegeRow,
    $$UserCollegesTableFilterComposer,
    $$UserCollegesTableOrderingComposer,
    $$UserCollegesTableAnnotationComposer,
    $$UserCollegesTableCreateCompanionBuilder,
    $$UserCollegesTableUpdateCompanionBuilder,
    (
      UserCollegeRow,
      BaseReferences<_$AppDatabase, $UserCollegesTable, UserCollegeRow>
    ),
    UserCollegeRow,
    PrefetchHooks Function()> {
  $$UserCollegesTableTableManager(_$AppDatabase db, $UserCollegesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserCollegesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserCollegesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserCollegesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> refId = const Value.absent(),
            Value<String> collegeId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> cardCountA = const Value.absent(),
            Value<int> cardCountB = const Value.absent(),
            Value<int> cardCountC = const Value.absent(),
            Value<String?> pdfVersion = const Value.absent(),
            Value<int?> pdfSize = const Value.absent(),
          }) =>
              UserCollegesCompanion(
            refId: refId,
            collegeId: collegeId,
            status: status,
            cardCountA: cardCountA,
            cardCountB: cardCountB,
            cardCountC: cardCountC,
            pdfVersion: pdfVersion,
            pdfSize: pdfSize,
          ),
          createCompanionCallback: ({
            Value<int> refId = const Value.absent(),
            required String collegeId,
            required String status,
            required int cardCountA,
            required int cardCountB,
            required int cardCountC,
            Value<String?> pdfVersion = const Value.absent(),
            Value<int?> pdfSize = const Value.absent(),
          }) =>
              UserCollegesCompanion.insert(
            refId: refId,
            collegeId: collegeId,
            status: status,
            cardCountA: cardCountA,
            cardCountB: cardCountB,
            cardCountC: cardCountC,
            pdfVersion: pdfVersion,
            pdfSize: pdfSize,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserCollegesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserCollegesTable,
    UserCollegeRow,
    $$UserCollegesTableFilterComposer,
    $$UserCollegesTableOrderingComposer,
    $$UserCollegesTableAnnotationComposer,
    $$UserCollegesTableCreateCompanionBuilder,
    $$UserCollegesTableUpdateCompanionBuilder,
    (
      UserCollegeRow,
      BaseReferences<_$AppDatabase, $UserCollegesTable, UserCollegeRow>
    ),
    UserCollegeRow,
    PrefetchHooks Function()>;
typedef $$QuietDaysTableCreateCompanionBuilder = QuietDaysCompanion Function({
  Value<int> day,
});
typedef $$QuietDaysTableUpdateCompanionBuilder = QuietDaysCompanion Function({
  Value<int> day,
});

class $$QuietDaysTableFilterComposer
    extends Composer<_$AppDatabase, $QuietDaysTable> {
  $$QuietDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnFilters(column));
}

class $$QuietDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $QuietDaysTable> {
  $$QuietDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get day => $composableBuilder(
      column: $table.day, builder: (column) => ColumnOrderings(column));
}

class $$QuietDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuietDaysTable> {
  $$QuietDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);
}

class $$QuietDaysTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QuietDaysTable,
    QuietDayRow,
    $$QuietDaysTableFilterComposer,
    $$QuietDaysTableOrderingComposer,
    $$QuietDaysTableAnnotationComposer,
    $$QuietDaysTableCreateCompanionBuilder,
    $$QuietDaysTableUpdateCompanionBuilder,
    (QuietDayRow, BaseReferences<_$AppDatabase, $QuietDaysTable, QuietDayRow>),
    QuietDayRow,
    PrefetchHooks Function()> {
  $$QuietDaysTableTableManager(_$AppDatabase db, $QuietDaysTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuietDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuietDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuietDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> day = const Value.absent(),
          }) =>
              QuietDaysCompanion(
            day: day,
          ),
          createCompanionCallback: ({
            Value<int> day = const Value.absent(),
          }) =>
              QuietDaysCompanion.insert(
            day: day,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QuietDaysTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QuietDaysTable,
    QuietDayRow,
    $$QuietDaysTableFilterComposer,
    $$QuietDaysTableOrderingComposer,
    $$QuietDaysTableAnnotationComposer,
    $$QuietDaysTableCreateCompanionBuilder,
    $$QuietDaysTableUpdateCompanionBuilder,
    (QuietDayRow, BaseReferences<_$AppDatabase, $QuietDaysTable, QuietDayRow>),
    QuietDayRow,
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
  $$PendingUploadsTableTableManager get pendingUploads =>
      $$PendingUploadsTableTableManager(_db, _db.pendingUploads);
  $$DailySessionsTableTableManager get dailySessions =>
      $$DailySessionsTableTableManager(_db, _db.dailySessions);
  $$ReviewLogTableTableManager get reviewLog =>
      $$ReviewLogTableTableManager(_db, _db.reviewLog);
  $$UserCollegesTableTableManager get userColleges =>
      $$UserCollegesTableTableManager(_db, _db.userColleges);
  $$QuietDaysTableTableManager get quietDays =>
      $$QuietDaysTableTableManager(_db, _db.quietDays);
}
