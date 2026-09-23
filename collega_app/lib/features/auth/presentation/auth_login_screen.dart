import 'package:flutter/services.dart' show TextInput, TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:collega_app/core/ui/collega_ui.dart';
import 'package:collega_app/features/auth/auth_providers.dart';
import 'package:collega_app/features/auth/domain/auth_state.dart';

/// Connexion (story 8.12) : autofill Trousseau / Face ID, erreurs dites à
/// l'endroit concerné (sous le champ, ou « pas de connexion »), jamais en toast.
/// Pas d'inscription : beta privée, comptes créés à la main.
class AuthLoginScreen extends ConsumerStatefulWidget {
  const AuthLoginScreen({super.key});

  @override
  ConsumerState<AuthLoginScreen> createState() => _AuthLoginScreenState();
}

class _AuthLoginScreenState extends ConsumerState<AuthLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordFocus = FocusNode();

  String? _emailError;
  String? _passwordError;

  /// Erreur qui ne vient pas d'un champ (réseau, trop d'essais, serveur).
  String? _formError;
  bool _submitting = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _emailError = email.isEmpty
          ? 'Saisis ton email.'
          : _emailPattern.hasMatch(email)
              ? null
              : _invalidEmail;
      _passwordError = password.isEmpty ? 'Saisis ton mot de passe.' : null;
      _formError = null;
    });
    if (_emailError != null || _passwordError != null) return;

    setState(() => _submitting = true);
    await ref.read(authProvider.notifier).login(email, password);
    if (!mounted) return;
    setState(() => _submitting = false);

    final auth = ref.read(authProvider).valueOrNull;
    if (auth == null) return;
    if (auth.isAuthenticated) {
      // Le Trousseau propose d'enregistrer les identifiants.
      TextInput.finishAutofillContext();
      context.go('/home');
      return;
    }
    CgHaptics.error();
    setState(() {
      switch (auth.loginError ?? LoginError.other) {
        case LoginError.invalidCredentials:
          _passwordError = 'Email ou mot de passe incorrect.';
        case LoginError.invalidEmail:
          _emailError = _invalidEmail;
        case LoginError.network:
          _formError = 'Pas de connexion pour l’instant. Réessaie quand le réseau revient.';
        case LoginError.tooManyAttempts:
          _formError = 'Trop d’essais. Réessaie dans une minute.';
        case LoginError.other:
          _formError = 'La connexion n’a pas abouti. Réessaie dans un instant.';
      }
    });
  }

  Future<void> _forgot() => showCgSheet<void>(
        context,
        title: 'Mot de passe oublié',
        builder: (context) {
          final c = CgTheme.of(context).colors;
          return Text(
            'Collega est en beta privée : demande un nouveau mot de passe à la personne qui t’a invitée.',
            style: CgType.body.copyWith(color: c.ink2),
          );
        },
        primary: Builder(
          builder: (s) => CgButton(label: 'Compris', onPressed: () => Navigator.of(s, rootNavigator: true).pop()),
        ),
      );

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = CgTheme.of(context).colors;
    // Chargé dès l'affichage : son chargement initial n'écrase pas le résultat
    // d'une connexion.
    ref.watch(authProvider);
    return ColoredBox(
      color: c.ground,
      child: CgPage(
        title: 'Connexion',
        subtitle: 'Beta privée · accès sur invitation',
        backLabel: 'Retour',
        onBack: _back,
        bottomAction: CgButton(label: 'Se connecter', loading: _submitting, onPressed: _submit),
        children: [
          const SizedBox(height: CgSpace.s5),
          const Align(alignment: Alignment.centerLeft, child: CgWordmark(height: _wordmarkHeight)),
          const SizedBox(height: CgSpace.s5),
          AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CgField(
                label: 'Email',
                kind: CgFieldKind.email,
                controller: _email,
                error: _emailError,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (_emailError != null) setState(() => _emailError = null);
                },
                onSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: CgSpace.s4),
              CgField(
                label: 'Mot de passe',
                kind: CgFieldKind.password,
                controller: _password,
                focusNode: _passwordFocus,
                error: _passwordError,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (_passwordError != null) setState(() => _passwordError = null);
                },
                onSubmitted: (_) => _submit(),
              ),
            ]),
          ),
          if (_formError != null) ...[
            const SizedBox(height: CgSpace.s4),
            Semantics(
              liveRegion: true,
              container: true,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CgIcon(CgIcons.warning, size: _iconSize, color: c.warningInk),
                const SizedBox(width: CgSpace.s2),
                Expanded(child: Text(_formError!, style: CgType.bodyS.copyWith(color: c.warningInk))),
              ]),
            ),
          ],
          const SizedBox(height: CgSpace.s3),
          Align(
            alignment: Alignment.centerLeft,
            child: CgButton(
              label: 'Mot de passe oublié ?',
              variant: CgButtonVariant.quiet,
              size: CgButtonSize.compact,
              expand: false,
              onPressed: _forgot,
            ),
          ),
          const SizedBox(height: CgSpace.section),
          CgButton(
            label: 'Essayer la démo',
            variant: CgButtonVariant.quiet,
            onPressed: () => context.push('/demo'),
          ),
        ],
      ),
    );
  }

  static const _iconSize = 18.0;
  static const _wordmarkHeight = 32.0;
  static const _invalidEmail = 'Cet email n’est pas valide.';
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
}
