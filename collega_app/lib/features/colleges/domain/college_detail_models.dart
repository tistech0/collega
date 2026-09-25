import 'package:collega_app/features/colleges/domain/card_type.dart';

class ItemModel {
  const ItemModel({
    required this.id,
    required this.collegeId,
    required this.itemNumber,
    required this.rang,
    this.chapterTitle,
    required this.ocrConfidenceScore,
    required this.lowConfidence,
    required this.cardCountA,
    required this.cardCountB,
    required this.cardCountC,
  });

  final String id;
  final String collegeId;
  final int itemNumber;
  final String rang;
  final String? chapterTitle;
  final double ocrConfidenceScore;
  final bool lowConfidence;
  final int cardCountA;
  final int cardCountB;
  final int cardCountC;

  int get totalCards => cardCountA + cardCountB + cardCountC;

  /// Fiches de rang [rang] (A, B ou C) — rang de la fiche, pas celui de l'item.
  int cardCountFor(String rang) => switch (rang) {
        'A' => cardCountA,
        'B' => cardCountB,
        'C' => cardCountC,
        _ => 0,
      };

  factory ItemModel.fromJson(Map<String, dynamic> json) => ItemModel(
        id: json['id'] as String,
        collegeId: json['college_id'] as String? ?? '',
        itemNumber: json['item_number'] as int,
        rang: json['rang'] as String,
        chapterTitle: json['chapter_title'] as String?,
        ocrConfidenceScore: (json['ocr_confidence_score'] as num?)?.toDouble() ?? 0.0,
        lowConfidence: json['low_confidence'] as bool,
        cardCountA: json['card_count_a'] as int? ?? 0,
        cardCountB: json['card_count_b'] as int? ?? 0,
        cardCountC: json['card_count_c'] as int? ?? 0,
      );
}

class FlashCardModel {
  const FlashCardModel({
    required this.id,
    required this.itemId,
    required this.collegeId,
    required this.cardType,
    required this.rang,
    required this.recto,
    required this.verso,
    required this.ocrConfidenceScore,
    required this.lowConfidence,
    this.userFeedback,
    this.drillLevel = 'new',
  });

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

  factory FlashCardModel.fromJson(Map<String, dynamic> json) => FlashCardModel(
        id: json['id'] as String,
        itemId: json['item_id'] as String,
        collegeId: json['college_id'] as String? ?? '',
        cardType: json['card_type'] as String,
        rang: json['rang'] as String,
        recto: json['recto'] as String,
        verso: json['verso'] as String,
        ocrConfidenceScore: (json['ocr_confidence_score'] as num?)?.toDouble() ?? 0.0,
        lowConfidence: json['low_confidence'] as bool,
        userFeedback: json['user_feedback'] as String?,
      );

  static const _absent = Object();

  FlashCardModel copyWith({
    String? id,
    String? itemId,
    String? collegeId,
    String? cardType,
    String? rang,
    String? recto,
    String? verso,
    double? ocrConfidenceScore,
    bool? lowConfidence,
    Object? userFeedback = _absent,
    String? drillLevel,
  }) =>
      FlashCardModel(
        id: id ?? this.id,
        itemId: itemId ?? this.itemId,
        collegeId: collegeId ?? this.collegeId,
        cardType: cardType ?? this.cardType,
        rang: rang ?? this.rang,
        recto: recto ?? this.recto,
        verso: verso ?? this.verso,
        ocrConfidenceScore: ocrConfidenceScore ?? this.ocrConfidenceScore,
        lowConfidence: lowConfidence ?? this.lowConfidence,
        userFeedback: identical(userFeedback, _absent) ? this.userFeedback : userFeedback as String?,
        drillLevel: drillLevel ?? this.drillLevel,
      );
}

sealed class CollegeDetailState {
  const CollegeDetailState();
}

class CollegeDetailLoading extends CollegeDetailState {
  const CollegeDetailLoading();
}

class CollegeDetailLoaded extends CollegeDetailState {
  const CollegeDetailLoaded({required this.items, this.selectedRang});
  final List<ItemModel> items;
  final String? selectedRang;

  List<ItemModel> get filteredItems => selectedRang == null
      ? items
      : items.where((i) => i.rang == selectedRang).toList();

}

class CollegeDetailEmpty extends CollegeDetailState {
  const CollegeDetailEmpty();
}

class CollegeDetailError extends CollegeDetailState {
  const CollegeDetailError({required this.message});
  final String message;
}

const _rangOrder = {'A': 0, 'B': 1, 'C': 2};

/// Fiches d'un item dans l'ordre d'affichage (chantier 4 § 7) : par type
/// ([CardType.sortOrder] : classique, cas clinique, définition ; inconnu = classique),
/// puis par rang de la fiche ; à égalité, l'ordre reçu est gardé.
List<FlashCardModel> sortCardsForList(List<FlashCardModel> cards) {
  final indexed = [for (var i = 0; i < cards.length; i++) (i, cards[i])];
  indexed.sort((a, b) {
    final byType = CardType.parse(a.$2.cardType).sortOrder.compareTo(CardType.parse(b.$2.cardType).sortOrder);
    if (byType != 0) return byType;
    final byRang = (_rangOrder[a.$2.rang] ?? 3).compareTo(_rangOrder[b.$2.rang] ?? 3);
    return byRang != 0 ? byRang : a.$1.compareTo(b.$1);
  });
  return [for (final (_, card) in indexed) card];
}
