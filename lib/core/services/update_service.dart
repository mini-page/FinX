import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// Holds information about an available app update.
class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.releaseUrl,
    this.releaseNotes,
  });

  /// Cleaned-up version string from the GitHub tag, e.g. `"2.2.0"`.
  final String latestVersion;

  /// GitHub HTML URL for the release page or APK asset.
  final String releaseUrl;

  /// Optional markdown release notes from the GitHub release body.
  final String? releaseNotes;
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Checks the GitHub Releases API to determine whether a newer version of
/// Expensio is available.
///
/// Returns [null] if the current version is already the latest, or if the
/// check cannot be completed (network error, unexpected response, etc.).
class UpdateService {
  static const _latestReleaseApiUrl =
      'https://api.github.com/repos/mini-page/Expensio/releases/latest';
  static const _releasesPageUrl =
      'https://github.com/mini-page/Expensio/releases/latest';

  static Future<UpdateInfo?> checkForUpdate() async {
    final client = http.Client();
    try {
      final response = await client.get(
        Uri.parse(_latestReleaseApiUrl),
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // tag_name can be "v2.2.0" or "2.2.0"
      final rawTag = (data['tag_name'] as String? ?? '').trim();
      final tagVersion = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;
      if (tagVersion.isEmpty) return null;

      final htmlUrl = (data['html_url'] as String?)?.trim() ?? _releasesPageUrl;
      final releaseNotes = data['body'] as String?;

      if (!_isNewerVersion(tagVersion, AppConstants.version)) return null;

      return UpdateInfo(
        latestVersion: tagVersion,
        releaseUrl: htmlUrl,
        releaseNotes: releaseNotes,
      );
    } catch (e, st) {
      assert(() {
        dev.log('UpdateService.checkForUpdate failed: $e', stackTrace: st);
        return true;
      }());
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Returns `true` when [latest] is strictly greater than [current].
  ///
  /// Both strings must be semver-compatible (e.g. `"2.1.0"`). Non-parseable
  /// versions are treated as equal → no update.
  static bool _isNewerVersion(String latest, String current) {
    final l = _parseVersion(latest);
    final c = _parseVersion(current);
    if (l == null || c == null) return false;
    for (var i = 0; i < 3; i++) {
      if (l[i] > c[i]) return true;
      if (l[i] < c[i]) return false;
    }
    return false;
  }

  static List<int>? _parseVersion(String v) {
    try {
      final parts = v.split('.');
      // Only the first three segments are significant; extras are ignored.
      final semver = parts.take(3).map(int.parse).toList();
      while (semver.length < 3) {
        semver.add(0);
      }
      return semver;
    } catch (_) {
      return null;
    }
  }
}

// ── Riverpod ──────────────────────────────────────────────────────────────────

/// Notifier that wraps the update check lifecycle.
///
/// Initial state is `AsyncValue.data(null)` — meaning "not checked yet".
/// Call [check] to trigger a network request; the state transitions through
/// `loading` → `data(UpdateInfo?)` / `error`.
class UpdateCheckerNotifier extends Notifier<AsyncValue<UpdateInfo?>> {
  @override
  AsyncValue<UpdateInfo?> build() => const AsyncValue.data(null);

  Future<void> check() async {
    state = const AsyncValue.loading();
    try {
      final info = await UpdateService.checkForUpdate();
      state = AsyncValue.data(info);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final updateCheckerProvider =
    NotifierProvider<UpdateCheckerNotifier, AsyncValue<UpdateInfo?>>(
  UpdateCheckerNotifier.new,
);
