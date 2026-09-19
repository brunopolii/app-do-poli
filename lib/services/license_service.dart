import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService {
  static const endpoint = 'https://polirotinas-license.brunopoli95.workers.dev';

  // Keep the original key for backward compatibility with already activated
  // installations.
  static const _licenseKey = 'polirotinas_license_key';
  static const _installationIdKey = 'polirotinas_installation_id';
  static const _licenseTypeKey = 'polirotinas_license_type';
  static const _expiresAtKey = 'polirotinas_license_expires_at';

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

  Future<String> storedLicenseType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_licenseTypeKey) ?? 'lifetime';
  }

  Future<DateTime?> storedExpiresAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_expiresAtKey);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  Future<bool> _cachedIsValid() async {
    final key = await storedLicenseKey();
    if (key == null || key.isEmpty) return false;

    final type = await storedLicenseType();
    if (type != 'monthly') return true;

    final expiresAt = await storedExpiresAt();
    if (expiresAt == null) return false;
    return DateTime.now().toUtc().isBefore(expiresAt);
  }

  Future<void> _saveLicense({
    required String key,
    required String type,
    required String? expiresAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_licenseKey, key);
    await prefs.setString(_licenseTypeKey, type);

    if (expiresAt == null || expiresAt.isEmpty) {
      await prefs.remove(_expiresAtKey);
    } else {
      await prefs.setString(_expiresAtKey, expiresAt);
    }
  }

  Future<void> _clearLicense() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_licenseKey);
    await prefs.remove(_licenseTypeKey);
    await prefs.remove(_expiresAtKey);
  }

  Future<bool> isActivated() async => _cachedIsValid();

  /// Loads the local authorization first, then tries a short online
  /// revalidation. A network failure does not block offline use.
  Future<bool> initialize() async {
    final cached = await _cachedIsValid();
    final key = await storedLicenseKey();
    if (key == null || key.isEmpty) return false;

    try {
      final installationId = await _installationId();
      final response = await http
          .post(
            Uri.parse(endpoint + '/validate'),
            headers: const {'content-type': 'application/json'},
            body: jsonEncode({
              'license_key': key,
              'installation_id': installationId,
            }),
          )
          .timeout(const Duration(seconds: 4));

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) data = decoded;
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['valid'] == true) {
        await _saveLicense(
          key: key,
          type: String(data['license_type'] ?? 'lifetime'),
          expiresAt: data['expires_at'] as String?,
        );
        return true;
      }

      if (response.statusCode == 403 || response.statusCode == 409) {
        await _clearLicense();
        return false;
      }

      // A transient server error should not destroy a locally valid license.
      return cached;
    } catch (_) {
      return cached;
    }
  }

  Future<LicenseActivationResult> activate(String rawKey) async {
    final key = rawKey.trim().toUpperCase();
    if (key.isEmpty) {
      return const LicenseActivationResult.failure(
        'Digite sua chave de ativação.',
      );
    }

    try {
      final installationId = await _installationId();
      final response = await http
          .post(
            Uri.parse(endpoint + '/activate'),
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

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['activated'] == true) {
        await _saveLicense(
          key: key,
          type: String(data['license_type'] ?? 'lifetime'),
          expiresAt: data['expires_at'] as String?,
        );
        return LicenseActivationResult.success(
          key,
          String(data['license_type'] ?? 'lifetime'),
          data['expires_at'] as String?,
        );
      }

      switch (data['error']) {
        case 'invalid_license':
          return const LicenseActivationResult.failure(
            'Chave inválida. Confira a chave e tente novamente.',
          );
        case 'license_revoked':
          return const LicenseActivationResult.failure(
            'Esta licença foi cancelada ou reembolsada.',
          );
        case 'license_expired':
          return const LicenseActivationResult.failure(
            'Esta licença mensal expirou. Renove sua assinatura para continuar.',
          );
        case 'license_already_activated':
          return const LicenseActivationResult.failure(
            'Esta chave já está ativada em outro aparelho.',
          );
        default:
          return LicenseActivationResult.failure(
            'Não foi possível ativar a licença (HTTP ' +
                response.statusCode.toString() +
                ').',
          );
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
  final String licenseType;
  final String? expiresAt;

  const LicenseActivationResult._(
    this.ok,
    this.message,
    this.key,
    this.licenseType,
    this.expiresAt,
  );

  const LicenseActivationResult.success(
    String key,
    String licenseType,
    String? expiresAt,
  ) : this._(
          true,
          'Licença ativada com sucesso.',
          key,
          licenseType,
          expiresAt,
        );

  const LicenseActivationResult.failure(String message)
      : this._(false, message, null, 'lifetime', null);
}
