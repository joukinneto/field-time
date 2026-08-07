import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_assets.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';
import 'package:jkdd_field_time_records_production/src/auth/auth_session.dart';
import 'package:jkdd_field_time_records_production/src/localization/app_language.dart';

final class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

final class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: AutofillGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Image.asset(
                          AppAssets.fieldTimeLogoHorizontal,
                          height: 54,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.amber.withValues(alpha: .14),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.amber.withValues(alpha: .45),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            child: Text(
                              context.tr('auth.testEnvironment'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: AppColors.navy),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        TextField(
                          key: const ValueKey('login-username'),
                          controller: _username,
                          autofillHints: const [AutofillHints.username],
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: context.tr('auth.username'),
                            prefixIcon:
                                const Icon(Icons.alternate_email_outlined),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextField(
                          key: const ValueKey('login-password'),
                          controller: _password,
                          autofillHints: const [AutofillHints.password],
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: context.tr('auth.password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? context.tr('auth.showPassword')
                                  : context.tr('auth.hidePassword'),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            key: const ValueKey('forgot-password'),
                            onPressed: _recoverPassword,
                            icon: const Icon(Icons.help_outline, size: 18),
                            label: const Text('Esqueci minha senha'),
                          ),
                        ),
                        if (session.errorKey != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            context.tr(session.errorKey!),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppColors.red),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton.icon(
                          key: const ValueKey('login-submit'),
                          onPressed: session.authenticating ? null : _submit,
                          icon: session.authenticating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.login_outlined),
                          label: Text(context.tr('auth.login')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    await ref
        .read(authSessionProvider.notifier)
        .login(_username.text, _password.text);
  }

  Future<void> _recoverPassword() async {
    final email = TextEditingController(text: _username.text.trim());
    final submitted = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar senha'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Informe o e-mail/usuário cadastrado para recuperar o acesso.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail ou usuário',
                prefixIcon: Icon(Icons.alternate_email_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, email.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    email.dispose();
    if (!mounted || submitted == null || submitted.isEmpty) return;

    HomologationAccount? account;
    for (final item in AuthSessionController.accounts) {
      if (item.username.toLowerCase() == submitted.toLowerCase()) {
        account = item;
        break;
      }
    }

    if (account == null) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Usuário não encontrado'),
          content: const Text(
            'Não existe uma conta de teste cadastrada com esse e-mail/usuário.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    _username.text = account.username;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acesso de teste recuperado'),
        content: const Text(
          'Neste ambiente de homologação, a senha padrão foi restaurada para Test123!. '
          'Na versão de produção, a recuperação será feita por link/código seguro enviado ao usuário.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar ao login'),
          ),
        ],
      ),
    );
  }
}
