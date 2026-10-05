import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wrap do `flutter_secure_storage` com chaves canônicas.
class SecureTokenStorage {
  const SecureTokenStorage({this.storage = const FlutterSecureStorage()});

  final FlutterSecureStorage storage;

  static const _kToken = 'unisism.token';
  static const _kMatricula = 'unisism.matricula';
  static const _kSenha = 'unisism.senha_segura';
  static const _kBiometriaAtiva = 'unisism.biometria_ativa';

  Future<String?> readToken() => storage.read(key: _kToken);
  Future<void> writeToken(String value) =>
      storage.write(key: _kToken, value: value);

  Future<String?> readMatricula() => storage.read(key: _kMatricula);
  Future<void> writeMatricula(String value) =>
      storage.write(key: _kMatricula, value: value);

  Future<bool> isBiometriaAtiva() async {
    final val = await storage.read(key: _kBiometriaAtiva);
    return val == 'true';
  }

  Future<void> setBiometriaAtiva(bool value) =>
      storage.write(key: _kBiometriaAtiva, value: value ? 'true' : 'false');

  Future<void> saveCredenciaisBiometria({
    required String identificador,
    required String senha,
  }) async {
    await writeMatricula(identificador);
    await storage.write(key: _kSenha, value: senha);
    await setBiometriaAtiva(true);
  }

  Future<({String identificador, String senha})?> getCredenciaisBiometria() async {
    final ativa = await isBiometriaAtiva();
    if (!ativa) return null;
    final id = await readMatricula();
    final senha = await storage.read(key: _kSenha);
    if (id == null || id.isEmpty || senha == null || senha.isEmpty) {
      return null;
    }
    return (identificador: id, senha: senha);
  }

  Future<void> clearBiometria() async {
    await storage.delete(key: _kBiometriaAtiva);
    await storage.delete(key: _kSenha);
  }

  Future<void> clear({bool manterCredenciais = true}) async {
    await storage.delete(key: _kToken);
    if (!manterCredenciais) {
      await storage.delete(key: _kMatricula);
      await clearBiometria();
    }
  }
}
