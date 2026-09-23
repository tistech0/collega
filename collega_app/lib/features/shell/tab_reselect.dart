import 'package:flutter/widgets.dart';

/// Onglet re-tapé alors qu'il est déjà actif : l'écran remonte en haut
/// (spec § Navigation). Le shell incrémente le compteur de l'onglet ; l'écran
/// écoute [TabReselectScope.listenableOf].
class TabReselect extends ChangeNotifier {
  int index = -1;

  void reselect(int tab) {
    index = tab;
    notifyListeners();
  }
}

class TabReselectScope extends InheritedWidget {
  const TabReselectScope({super.key, required this.reselect, required super.child});

  final TabReselect reselect;

  static TabReselect? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TabReselectScope>()?.reselect;

  @override
  bool updateShouldNotify(TabReselectScope oldWidget) => reselect != oldWidget.reselect;
}

/// Remonte en haut de [scrollController] quand l'onglet [tabIndex] est re-tapé.
mixin TabReselectScrollMixin<T extends StatefulWidget> on State<T> {
  TabReselect? _reselect;

  int get tabIndex;
  ScrollController get scrollController;

  /// Durée de la remontée (mouvement réduit respecté par l'écran).
  Duration get reselectDuration;
  Curve get reselectCurve;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reselect = TabReselectScope.maybeOf(context);
    if (reselect != _reselect) {
      _reselect?.removeListener(_onReselect);
      _reselect = reselect?..addListener(_onReselect);
    }
  }

  void _onReselect() {
    if (_reselect?.index == tabIndex && scrollController.hasClients) {
      scrollController.animateTo(0, duration: reselectDuration, curve: reselectCurve);
    }
  }

  @override
  void dispose() {
    _reselect?.removeListener(_onReselect);
    super.dispose();
  }
}
