import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// Verifica se o dispositivo possui hardware e suporte a biometria.
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Verifica se o dispositivo possui reconhecimento facial (Face ID).
  Future<bool> hasFaceId() async {
    try {
      final biometrics = await _auth.getAvailableBiometrics();
      return biometrics.contains(BiometricType.face);
    } on PlatformException {
      return false;
    }
  }

  /// Retorna o rótulo amigável da biometria disponível no dispositivo.
  Future<String> getBiometricLabel() async {
    final face = await hasFaceId();
    return face ? 'Face ID' : 'Biometria';
  }

  /// Dispara o prompt biométrico do sistema operacional (Face ID / Fingerprint).
  Future<bool> authenticate({String? reason}) async {
    try {
      final isFace = await hasFaceId();
      final defaultReason = isFace
          ? 'Use o Face ID para entrar no UNISISM Motorista'
          : 'Toque no sensor biométrico para entrar no UNISISM Motorista';

      return await _auth.authenticate(
        localizedReason: reason ?? defaultReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException {
      return false;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});
