import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/network_profile.dart';

/// Read-through cache for the connections list so a cold start with no network
/// still paints. Write-through on every successful fetch (first page only).
/// Same encrypted-box pattern as [ChatCache].
class NetworkCache {
  static const boxName = 'network_cache';
  Box<dynamic> get _box => Hive.box(boxName);

  static const _connectionsKey = 'connections';

  Future<void> putConnections(List<PersonCard> list) => _box.put(
        _connectionsKey,
        jsonEncode([for (final c in list) _encode(c)]),
      );

  List<PersonCard>? connections() {
    final raw = _box.get(_connectionsKey) as String?;
    if (raw == null) return null;
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          PersonCard.fromJson((e as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return null; // schema drift → cache miss
    }
  }

  Map<String, dynamic> _encode(PersonCard c) => {
        'id': c.id,
        'full_name': c.fullName,
        'headline': c.headline,
        'specialty': c.specialty,
        'location_label': c.locationLabel,
        'avatar_color': c.avatarColor,
        'avatar_url': c.avatarUrl,
        'avatar_presigned_url': c.avatarPresignedUrl,
        'degree': c.degree.wire,
        'mutual_count': c.mutualCount,
      };

  Future<void> clear() => _box.clear();
}
