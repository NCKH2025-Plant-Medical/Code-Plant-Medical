// lib/core/cluster/cluster_item.dart
import 'package:latlong2/latlong.dart';
import 'cluster_manager.dart';
import 'geohash.dart';

mixin ClusterItem {
  LatLng get location;

  String? _geohash;
  String get geohash => _geohash ??= Geohash.encode(
    location,
    codeLength: MapClusterManager.precision,
  );
}
