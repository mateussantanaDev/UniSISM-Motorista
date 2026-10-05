import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisism_motorista/data/auth/secure_token_storage.dart';

void main() {
  group('SecureTokenStorage', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('salva e recupera credenciais para login biométrico', () async {
      const storage = SecureTokenStorage();

      expect(await storage.isBiometriaAtiva(), isFalse);
      expect(await storage.getCredenciaisBiometria(), isNull);

      await storage.saveCredenciaisBiometria(
        identificador: 'MOT-123456',
        senha: 'MinhaSenhaSegura1',
      );

      expect(await storage.isBiometriaAtiva(), isTrue);
      final creds = await storage.getCredenciaisBiometria();
      expect(creds, isNotNull);
      expect(creds?.identificador, 'MOT-123456');
      expect(creds?.senha, 'MinhaSenhaSegura1');

      // Logout normal mantém credenciais biométricas salvas
      await storage.clear(manterCredenciais: true);
      final posLogout = await storage.getCredenciaisBiometria();
      expect(posLogout, isNotNull);

      // Limpeza completa de biometria
      await storage.clearBiometria();
      expect(await storage.isBiometriaAtiva(), isFalse);
      expect(await storage.getCredenciaisBiometria(), isNull);
    });
  });
}
