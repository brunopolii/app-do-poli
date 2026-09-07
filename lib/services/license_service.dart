import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static const endpoint = 'https://polirotinas-license.brunopoli95.workers.dev';
  static const _licenseKey = 'polirotinas_license_key';
  static const _installationIdKey = 'polirotinas_installation_id';

  Future<String> _installationId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_installationIdKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final id = base64UrlEncode(bytes).replaceAll('=', '');
    await prefs.setString(_installationIdKey, id);
    return id;
  }

  Future<String?> storedLicenseKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_licenseKey);
  }

  Future<bool> isActivated() async => (await storedLicenseKey()) != null;

  Future<LicenseActivationResult> activate(String rawKey) async {
    final key = rawKey.trim().toUpperCase();
    if (key.isEmpty) return const LicenseActivationResult.failure('Digite sua chave de ativação.');

    try {
      final installationId = await _installationId();
      final response = await http
          .post(
            Uri.parse('$endpoint/activate'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'license_key': key,
              'installation_id': installationId,
            }),
          )
          .timeout(const Duration(seconds: 15));

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      }

      if (response.statusCode >= 200 && response.statusCode < 300 && data['activated'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_licenseKey, key);
        return LicenseActivationResult.success(key);
      }

      switch (data['error']) {
        case 'invalid_license':
          return const LicenseActivationResult.failure('Chave inválida. Confira a chave e tente novamente.');
        case 'license_revoked':
          return const LicenseActivationResult.failure('Esta licença foi cancelada ou reembolsada.');
        case 'license_already_activated':
          return const LicenseActivationResult.failure('Esta chave já está ativada em outro aparelho.');
        default:
          return LicenseActivationResult.failure('Não foi possível ativar a licença (HTTP ${response.statusCode}).');
      }
    } catch (_) {
      return const LicenseActivationResult.failure(
        'Não foi possível conectar ao servidor. A primeira ativação precisa de internet.',
      );
    }
  }
}

class LicenseActivationResult {
  final bool ok;
  final String message;
  final String? key;

  const LicenseActivationResult._(this.ok, this.message, this.key);

  const LicenseActivationResult.success(String key)
      : this._(true, 'Licença ativada com sucesso.', key);

  const LicenseActivationResult.failure(String message) : this._(false, message, null);
}
