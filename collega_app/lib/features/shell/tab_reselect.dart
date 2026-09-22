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
