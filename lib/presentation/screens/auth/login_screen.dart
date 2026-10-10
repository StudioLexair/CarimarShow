import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/app_user.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import 'auth_widgets.dart';

/// Acceso con correo y contraseña.
///
/// Cuando no hay backend configurado, el registro se oculta y se ofrece la
/// sesión local, de modo que la app nunca quede bloqueada por falta de
/// configuración.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);

    // Con sesión iniciada el router redirige solo: no se navega desde aquí para
    // no provocar una doble transición.
    if (ok) {
      await ref.read(sessionModeProvider.notifier).exitGuest();
    }
    if (ok && mounted) _password.clear();
  }

  Future<void> _guest() async {
    FocusScope.of(context).unfocus();
    // Primero la bandera: así continueAsGuest ya resuelve el repositorio local
    // aunque haya Supabase configurado.
    await ref.read(sessionModeProvider.notifier).enterGuest();
    await ref.read(authControllerProvider.notifier).continueAsGuest();
  }

  /// Confirmación del modo invitado, con la letra pequeña clara.
  ///
  /// El modo invitado ya existía, pero entraba directo sin explicar la
  /// consecuencia: sin cuenta no hay servidor, así que la lista vive solo en
  /// el dispositivo y no se puede recuperar al cambiar de teléfono. Mejor
  /// decirlo antes de entrar que después de perder los datos.
  Future<void> _confirmGuest(BuildContext context) async {
    final bool? go = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Modo invitado'),
        content: const Text(
          'Puedes usar la aplicación sin crear una cuenta, pero tu lista, '
          'tu progreso y tus preferencias se guardarán SOLO en este '
          'dispositivo: no se suben a ningún servidor.\n\n'
          'Si desinstalas la aplicación, restableces el teléfono o lo '
          'pierdes, NO podrás recuperar esos datos. Con una cuenta creada, '
          'todo se sincroniza y lo recuperas en cualquier dispositivo.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Entrar como invitado'),
          ),
        ],
      ),
    );
    if (go == true) await _guest();
  }

  Future<void> _resetPassword() async {
    final String email = _email.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe primero tu correo electrónico.')),
      );
      return;
    }
    final bool sent = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Si el correo existe, te hemos enviado un enlace para restablecerla.'
              : ref.read(authControllerProvider).error ??
                    'No se pudo enviar el correo.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState auth = ref.watch(authControllerProvider);
    final bool accountsEnabled = ref.watch(accountsEnabledProvider);
    final AppUser? user = ref.watch(currentUserProvider);

    // Si la sesión se restaura mientras se mira esta pantalla, el router ya se
    // encarga de salir; aquí solo se evita pintar el formulario encima.
    if (user != null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const AuthHeader(
                      title: Strings.login,
                      subtitle:
                          'Entra para sincronizar Mi lista entre dispositivos.',
                    ),
                    const SizedBox(height: 28),

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
                      autofillHints: const <String>[AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      validator: Validators.required('Introduce tu contraseña'),
                      decoration: InputDecoration(
                        labelText: Strings.password,
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

                    if (auth.hasError) ...<Widget>[
                      const SizedBox(height: 16),
                      InlineAuthError(message: auth.error!),
                    ],

                    const SizedBox(height: 24),

                    FilledButton(
                      onPressed: auth.isSubmitting ? null : _submit,
                      child: auth.isSubmitting
                          ? const SubmitSpinner()
                          : const Text(Strings.login),
                    ),

                    if (accountsEnabled) ...<Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: auth.isSubmitting ? null : _resetPassword,
                          child: const Text(Strings.forgotPassword),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            Strings.noAccount,
                            style: context.text.bodySmall,
                          ),
                          TextButton(
                            onPressed: auth.isSubmitting
                                ? null
                                : () => context.pushReplacement('/register'),
                            child: const Text(Strings.register),
                          ),
                        ],
                      ),
                    ],

                    const AuthDivider(),

                    OutlinedButton.icon(
                      onPressed: auth.isSubmitting
                          ? null
                          : () => _confirmGuest(context),
                      icon: const Icon(Icons.person_outline_rounded, size: 20),
                      label: const Text('Entrar como invitado'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      accountsEnabled
                          ? 'Como invitado todo se guarda solo en este dispositivo.'
                          : 'Sin servidor configurado: todo se guarda en este dispositivo.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.pal.textDisabled,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (!accountsEnabled) ...<Widget>[
                      const SizedBox(height: 18),
                      const NoBackendNotice(),
                    ],

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
}
