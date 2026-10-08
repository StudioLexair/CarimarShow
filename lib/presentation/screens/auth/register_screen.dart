import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_providers.dart';
import 'auth_widgets.dart';

/// Alta de cuenta nueva.
///
/// Si el proyecto de Supabase exige confirmación por correo, el repositorio
/// devuelve un fallo informativo y aquí se muestra en pantalla completa, porque
/// «revisa tu correo» no es un error sino el siguiente paso.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;
  bool _accepted = false;

  /// Se activa cuando el registro quedó pendiente de confirmar el correo.
  bool _pendingConfirmation = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// 0–1 según lo cerca que esté la contraseña de cumplir los requisitos.
  double get _passwordStrength {
    final String value = _password.text;
    if (value.isEmpty) return 0;
    int score = 0;
    if (value.length >= 8) score++;
    if (value.length >= 12) score++;
    if (value.contains(RegExp(r'\d'))) score++;
    if (value.contains(RegExp(r'[A-Z]'))) score++;
    if (value.contains(RegExp(r'[^\w\s]'))) score++;
    return (score / 5).clamp(0.0, 1.0);
  }

  Color get _strengthColor {
    final double strength = _passwordStrength;
    if (strength >= 0.8) return AppColors.success;
    if (strength >= 0.5) return AppColors.warning;
    return AppColors.danger;
  }

  Future<void> _submit() async {
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acepta las condiciones para continuar.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );

    if (!mounted) return;
    if (ok) return; // El router redirige solo.

    final String? error = ref.read(authControllerProvider).error;
    if (error != null && error.toLowerCase().contains('correo')) {
      setState(() => _pendingConfirmation = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authControllerProvider);
    final bool accountsEnabled = ref.watch(accountsEnabledProvider);

    // Sin backend no tiene sentido ofrecer registro: se reconduce al acceso,
    // que explica el modo local.
    if (!accountsEnabled) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Padding(padding: EdgeInsets.all(32), child: NoBackendNotice()),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: FilledButton(
              onPressed: () => context.pushReplacement('/login'),
              child: const Text('Volver al acceso'),
            ),
          ),
        ),
      );
    }

    if (_pendingConfirmation) return _buildPendingConfirmation(context);

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.register)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const AuthHeader(
                      title: Strings.register,
                      subtitle:
                          'Crea tu cuenta para llevar Mi lista a todos tus dispositivos.',
                    ),
                    const SizedBox(height: 28),

                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const <String>[AutofillHints.name],
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: Validators.minLength(2, 'Mínimo 2 caracteres'),
                      decoration: const InputDecoration(
                        labelText: Strings.displayName,
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const <String>[AutofillHints.email],
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: Validators.email(),
                      decoration: const InputDecoration(
                        labelText: Strings.email,
                        hintText: 'tu@correo.com',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const <String>[AutofillHints.newPassword],
                      onFieldSubmitted: (_) => _submit(),
                      onChanged: (_) => setState(() {}),
                      validator: Validators.password(),
                      decoration: InputDecoration(
                        labelText: Strings.password,
                        helperText: 'Mínimo 8 caracteres y al menos un número',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),

                    if (_password.text.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: _passwordStrength,
                          ),
                          duration: const Duration(milliseconds: 220),
                          builder: (BuildContext context, double value, _) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 4,
                                backgroundColor: AppColors.surfaceHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _strengthColor,
                                ),
                              ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    CheckboxListTile(
                      value: _accepted,
                      onChanged: (bool? value) =>
                          setState(() => _accepted = value ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      activeColor: AppColors.crimson,
                      title: Text(
                        'Acepto las condiciones de uso y la política de privacidad.',
                        style: context.text.bodySmall,
                      ),
                    ),

                    if (auth.hasError) ...<Widget>[
                      const SizedBox(height: 12),
                      InlineAuthError(message: auth.error!),
                    ],

                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: auth.isSubmitting ? null : _submit,
                      child: auth.isSubmitting
                          ? const SubmitSpinner()
                          : const Text('Crear cuenta'),
                    ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(Strings.hasAccount, style: context.text.bodySmall),
                        TextButton(
                          onPressed: auth.isSubmitting
                              ? null
                              : () => context.pushReplacement('/login'),
                          child: const Text(Strings.login),
                        ),
                      ],
                    ),

                    SizedBox(height: context.gutter),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingConfirmation(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 36,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Revisa tu correo',
                  style: context.text.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Hemos enviado un enlace de confirmación a '
                  '${_email.text.trim()}. Ábrelo para activar tu cuenta y '
                  'después vuelve aquí.',
                  style: context.text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => context.pushReplacement('/login'),
                  child: const Text('Ya la he confirmado'),
                ),
                TextButton(
                  onPressed: () => setState(() => _pendingConfirmation = false),
                  child: const Text('Volver al formulario'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
