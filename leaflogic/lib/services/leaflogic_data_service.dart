import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_constants.dart';

class UserLeafRow {
  UserLeafRow({
    required this.id,
    required this.storagePath,
    required this.createdAt,
    required this.signedUrl,
    this.predictedLabel,
    this.predictedConfidence,
    this.predictedAt,
  });

  final String id;
  final String storagePath;
  final DateTime createdAt;
  final String signedUrl;
  final String? predictedLabel;
  final double? predictedConfidence;
  final DateTime? predictedAt;

  bool get hasPrediction =>
      predictedLabel != null && predictedLabel!.isNotEmpty && predictedConfidence != null;
}

/// Supabase reads / uploads for LeafLogic.
class LeafLogicDataService {
  LeafLogicDataService(this._client);

  final SupabaseClient _client;

  static const _uuid = Uuid();

  /// Global catalog count + current user's image count (RPC).
  Future<Map<String, int>> fetchDashboardStats() async {
    final raw = await _client.rpc('dashboard_stats');
    final m = Map<String, dynamic>.from(raw as Map);
    int n(dynamic v) => (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return {
      'catalog_diseases': n(m['catalog_diseases']),
      'registered_profiles': n(m['registered_profiles']),
      'my_leaf_images': n(m['my_leaf_images']),
    };
  }

  /// Ensures a `profiles` row exists (backup if DB trigger is missing).
  Future<void> ensureProfileRow() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final name = user.userMetadata?['full_name'] as String? ??
        user.userMetadata?['name'] as String? ??
        (user.email != null ? user.email!.split('@').first : 'LeafLogic');
    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': name,
    });
  }

  Future<List<UserLeafRow>> listMyLeafImages({int signedUrlSeconds = 3600}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final rows = await _client
        .from('user_images')
        .select('id, storage_path, created_at, predicted_label, predicted_confidence, predicted_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final list = <UserLeafRow>[];
    for (final row in (rows as List<dynamic>)) {
      final m = Map<String, dynamic>.from(row as Map);
      final path = m['storage_path'] as String;
      final signed = await _client.storage
          .from(AppConstants.storageBucketLeafImages)
          .createSignedUrl(path, signedUrlSeconds);
      list.add(
        UserLeafRow(
          id: m['id'] as String,
          storagePath: path,
          createdAt: DateTime.parse(m['created_at'] as String),
          signedUrl: signed,
          predictedLabel: m['predicted_label'] as String?,
          predictedConfidence: (m['predicted_confidence'] as num?)?.toDouble(),
          predictedAt: m['predicted_at'] != null
              ? DateTime.parse(m['predicted_at'] as String)
              : null,
        ),
      );
    }
    return list;
  }

  /// Uploads bytes to `leaf-images/{uid}/{uuid}.ext` and inserts `user_images`.
  /// Optionally records the on-device prediction at the same time.
  Future<void> uploadLeafImage({
    required Uint8List bytes,
    required String contentType,
    required String extension,
    String? predictedLabel,
    double? predictedConfidence,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    final objectPath = '${user.id}/${_uuid.v4()}.$extension';
    await _client.storage.from(AppConstants.storageBucketLeafImages).uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    final insertRow = <String, dynamic>{
      'user_id': user.id,
      'storage_path': objectPath,
    };
    if (predictedLabel != null && predictedConfidence != null) {
      insertRow['predicted_label'] = predictedLabel;
      insertRow['predicted_confidence'] = predictedConfidence;
      insertRow['predicted_at'] = DateTime.now().toUtc().toIso8601String();
    }

    await _client.from('user_images').insert(insertRow);
  }

  /// Updates an existing user_images row with a fresh prediction. Used by the
  /// Library's per-card "Classify" / "Re-classify" button.
  Future<void> updatePrediction({
    required String rowId,
    required String label,
    required double confidence,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    await _client.from('user_images').update({
      'predicted_label': label,
      'predicted_confidence': confidence,
      'predicted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', rowId).eq('user_id', user.id);
  }

  /// Downloads the bytes of a previously-uploaded leaf image so the on-device
  /// classifier can re-run on it.
  Future<Uint8List> fetchLeafImageBytes(String signedUrl) async {
    final res = await http.get(Uri.parse(signedUrl));
    if (res.statusCode != 200) {
      throw StateError('Image fetch failed (${res.statusCode}).');
    }
    return res.bodyBytes;
  }

  /// Removes the object from Storage, then the `user_images` row (RLS must allow both).
  Future<void> deleteLeafImage({
    required String rowId,
    required String storagePath,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    try {
      await _client.storage.from(AppConstants.storageBucketLeafImages).remove([storagePath]);
    } catch (_) {
      // File may already be removed; still delete the catalog row.
    }

    await _client.from('user_images').delete().eq('id', rowId).eq('user_id', user.id);
  }
}
