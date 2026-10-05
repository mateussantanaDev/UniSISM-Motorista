import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../data/auth/biometric_service.dart';
import '../../../data/auth/secure_token_storage.dart';
import '../../providers/auth_provider.dart';
import '../../providers/toast_controller.dart';
import '../../widgets/form_field.dart';
import '../../widgets/primary_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _matriculaCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _storage = const SecureTokenStorage();
  bool _loading = false;
  String? _erro;

  bool _biometriaDisponivel = false;
  String _rotuloBiometria = 'Biometria';
  bool _lembrarBiometria = true;
  ({String identificador, String senha})? _credenciaisSalvas;

  @override
  void initState() {
    super.initState();
    final cacheada = ref.read(authControllerProvider).matriculaCacheada;
    if (cacheada != null) _matriculaCtrl.text = cacheada;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checarBiometria());
  }

  Future<void> _checarBiometria() async {
    final bioSvc = ref.read(biometricServiceProvider);
    final disponivel = await bioSvc.isAvailable();
    if (!mounted) return;

    if (disponivel) {
      final rotulo = await bioSvc.getBiometricLabel();
      final creds = await _storage.getCredenciaisBiometria();
      if (!mounted) return;
      setState(() {
        _biometriaDisponivel = true;
        _rotuloBiometria = rotulo;
        _credenciaisSalvas = creds;
      });

      if (creds != null) {
        _matriculaCtrl.text = creds.identificador;
        _senhaCtrl.text = creds.senha;
        await _tentarLoginBiometrico(silent: true);
      }
    }
  }

  Future<void> _tentarLoginBiometrico({bool silent = false}) async {
    if (_loading || _credenciaisSalvas == null) return;

    final bioSvc = ref.read(biometricServiceProvider);
    final autenticado = await bioSvc.authenticate(
      reason: 'Use $_rotuloBiometria para acessar suas viagens no UNISISM',
    );

    if (!autenticado) {
      if (!silent && mounted) {
        ref.read(toastControllerProvider.notifier).warning(
          'Autenticação com $_rotuloBiometria cancelada.',
          title: 'Não autenticado',
        );
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;
      _erro = null;
    });

    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      await ref.read(authControllerProvider.notifier).login(
        matricula: _credenciaisSalvas!.identificador,
        senha: _credenciaisSalvas!.senha,
        salvarBiometria: true,
      );
    } on ApiException catch (e, st) {
      debugPrint('[LOGIN-BIO] ApiException: ${e.code} · ${e.message}\n$st');
      final msg = e.mensagemAmigavel;
      if (mounted) setState(() => _erro = msg);
      toasts.error(msg, title: _toastTitleFor(e));
    } catch (e, st) {
      debugPrint('[LOGIN-BIO] erro inesperado: $e\n$st');
      const msg = 'Não foi possível entrar. Digite sua senha.';
      if (mounted) setState(() => _erro = msg);
      toasts.error(msg, title: 'Erro');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _matriculaCtrl.dispose();
    _senhaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _matriculaCtrl.text.trim();
    final senha = _senhaCtrl.text;
    if (raw.isEmpty || senha.isEmpty) {
      ref.read(toastControllerProvider.notifier).warning(
        'Preencha CPF ou matrícula e senha pra continuar.',
        title: 'Faltam dados',
      );
      return;
    }

    final cleanDigits = raw.replaceAll(RegExp(r'\D'), '');
    final identificador = cleanDigits.length == 11 ? cleanDigits : raw;

    setState(() {
      _loading = true;
      _erro = null;
    });
    final toasts = ref.read(toastControllerProvider.notifier);
    try {
      await ref.read(authControllerProvider.notifier).login(
        matricula: identificador,
        senha: senha,
        salvarBiometria: _biometriaDisponivel && _lembrarBiometria,
      );
      if (!_lembrarBiometria) {
        await _storage.clearBiometria();
      }
      // Sucesso: o router redireciona automaticamente — nada a fazer aqui.
    } on ApiException catch (e, st) {
      debugPrint('[LOGIN] ApiException: ${e.code} · ${e.message}\n$st');
      final msg = e.mensagemAmigavel;
      if (mounted) setState(() => _erro = msg);
      toasts.error(msg, title: _toastTitleFor(e));
    } catch (e, st) {
      debugPrint('[LOGIN] erro inesperado: $e\n$st');
      const msg = 'Algo deu errado. Tente de novo em alguns segundos.';
      if (mounted) setState(() => _erro = msg);
      toasts.error(msg, title: 'Erro inesperado');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _toastTitleFor(ApiException e) {
    if (e.isOffline) return 'Sem internet';
    if (e.isUnauthorized) return 'Não autorizado';
    if (e.contaInativa) return 'Conta inativa';
    if (e.isServerError) return 'Servidor com problema';
    return 'Não foi possível entrar';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.pageBackground,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Header(),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Olá!',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFamily,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Tokens.textPrimary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Entre com seu CPF ou matrícula para ver suas viagens.',
                      style: AppTypography.bodySm.copyWith(
                        color: Tokens.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    AppFormField(
                      label: 'CPF ou Matrícula',
                      controller: _matriculaCtrl,
                      type: AppFieldType.text,
                      mono: true,
                      autofocus: _matriculaCtrl.text.isEmpty,
                      textInputAction: TextInputAction.next,
                      hint: 'Ex.: 000.000.000-00 ou MOT-345678',
                    ),
                    const SizedBox(height: 20),
                    AppFormField(
                      label: 'Senha',
                      controller: _senhaCtrl,
                      type: AppFieldType.password,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_biometriaDisponivel) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        onTap: () => setState(() => _lembrarBiometria = !_lembrarBiometria),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _lembrarBiometria,
                                activeColor: Tokens.blue900,
                                onChanged: (v) =>
                                    setState(() => _lembrarBiometria = v ?? false),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Entrar com $_rotuloBiometria nas próximas vezes',
                                style: AppTypography.bodySm.copyWith(
                                  color: Tokens.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_erro != null) ...[
                      const SizedBox(height: 16),
                      _ErroBanner(message: _erro!),
                    ],
                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Entrar',
                      leading: Icons.lock_open,
                      fullWidth: true,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    if (_biometriaDisponivel && _credenciaisSalvas != null) ...[
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Entrar com $_rotuloBiometria',
                        leading: _rotuloBiometria == 'Face ID'
                            ? Icons.face
                            : Icons.fingerprint,
                        variant: ButtonVariant.secondary,
                        fullWidth: true,
                        loading: _loading,
                        onPressed: () => _tentarLoginBiometrico(silent: false),
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _AjudaBlock(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Tokens.blue900,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Text(
                  'U',
                  style: TextStyle(
                    fontFamily: AppTypography.sansFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'UNISISM',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFamily,
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        letterSpacing: 3,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Motorista',
                      style: TextStyle(
                        fontFamily: AppTypography.sansFamily,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
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

class _ErroBanner extends StatelessWidget {
  const _ErroBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tokens.red50,
        border: Border.all(color: Tokens.red700, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Tokens.red800, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm.copyWith(
                color: Tokens.red900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AjudaBlock extends StatelessWidget {
  const _AjudaBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Tokens.blue50,
        border: Border(left: BorderSide(color: Tokens.blue900, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Tokens.blue900, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'É seu primeiro acesso? Use a senha que o gestor TFD te '
              'entregou. O app vai pedir uma senha nova logo depois.',
              style: AppTypography.bodySm.copyWith(color: Tokens.blue900),
            ),
          ),
        ],
      ),
    );
  }
}
