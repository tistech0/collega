import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:collega_app/core/theme/app_theme.dart';
import 'package:collega_app/features/auth/auth_providers.dart';

class AuthRegisterScreen extends ConsumerStatefulWidget {
  const AuthRegisterScreen({super.key});

  @override
  ConsumerState<AuthRegisterScreen> createState() => _AuthRegisterScreenState();
}

class _AuthRegisterScreenState extends ConsumerState<AuthRegisterScreen> {
  final _formKey = GlobalKey<ShadFormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;

    await ref.read(authProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;

    final authState = ref.read(authProvider).valueOrNull;
    if (authState == null) return;

    if (authState.errorMessage != null) {
      ShadToaster.of(context).show(
        ShadToast.destructive(
          title: const Text('Erreur'),
          description: Text(authState.errorMessage!),
        ),
      );
      return;
    }

    if (authState.isAuthenticated) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authProvider);
    final isLoading = authAsync.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.sectionSpacing * 2),
              Text(
                'Créer un compte',
                style: AppTypography.displayMedium(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Rejoignez AppMédecine',
                style: AppTypography.bodyMedium().copyWith(color: AppColors.secondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sectionSpacing * 2),
              if (isLoading)
                const ShadProgress()
              else
                ShadForm(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShadInputFormField(
                        controller: _emailController,
                        id: 'email',
                        label: const Text('Email'),
                        placeholder: const Text('prenom.nom@exemple.fr'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value.isEmpty) return "L'email est requis";
                          if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                            return 'Email invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      ShadInputFormField(
                        controller: _passwordController,
                        id: 'password',
                        label: const Text('Mot de passe'),
                        placeholder: const Text('8 caractères minimum'),
                        obscureText: true,
                        validator: (value) {
                          if (value.length < 8) {
                            return 'Le mot de passe doit contenir au moins 8 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.sectionSpacing),
                      ShadButton(
                        onPressed: _submit,
                        child: const Text("S'inscrire"),
                      ),
                      const SizedBox(height: 16),
                      ShadButton.ghost(
                        onPressed: () => context.go('/auth/login'),
                        child: const Text("J'ai déjà un compte → Connexion"),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
