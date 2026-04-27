// Stub — implémenté en Story 2.1
// Utilise ShadToast (erreur non-bloquante) ou ShadAlertDialog (erreur bloquante)
import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Erreur : $message'));
  }
}
