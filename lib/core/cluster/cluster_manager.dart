// lib/core/cluster/cluster_manager.dart
//
// Cluster manager dựa trên geohash cho flutter_map.
// Mỗi lần camera đổi vị trí/zoom → tính lại cluster và trả về List<Marker>.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'cluster.dart';
import 'cluster_item.dart';

class MapClusterManager<T extends ClusterItem> {
  MapClusterManager(
    this._items,
    this.updateMarkers, {
    required this.markerBuilder,
    this.levels = const [1, 4.25, 6.75, 8.25, 11.5, 14.5, 16.0, 16.5, 20.0],
    this.extraPercent = 0.5,
    this.stopClusteringZoom,
  }) : assert(levels.length <= precision);

  final Marker Function(PlantCluster<T>) markerBuilder;
  final void Function(List<Marker>) updateMarkers;
  final List<double> levels;
  final double extraPercent;
  final double? stopClusteringZoom;

  static final int precision = kIsWeb ? 12 : 20;

  MapController? _controller;
  Iterable<T> get items => _items;
  Iterable<T> _items;
  double _zoom = 15.0;

  final double _maxLng = 180 - pow(10, -10.0) as double;

  void setMapController(MapController controller, {bool withUpdate = true}) {
    _controller = controller;
    try {
      _zoom = controller.camera.zoom;
    } catch (_) {
      _zoom = 15.0;
    }
    if (withUpdate) updateMap();
  }

  void updateMap() {
    if (_controller == null) return;
    try {
      _zoom = _controller!.camera.zoom;
    } catch (_) {}
    final List<PlantCluster<T>> mapMarkers = getMarkers();
    final List<Marker> markers = mapMarkers
        .map((m) => markerBuilder(m))
        .toList();
    updateMarkers(markers);
  }

  void setItems(List<T> newItems) {
    _items = newItems;
    updateMap();
  }

  void onCameraMove(double zoom, {bool forceUpdate = false}) {
    _zoom = zoom;
    if (forceUpdate) {
      updateMap();
    }
  }

  List<PlantCluster<T>> getMarkers() {
    if (_controller == null) return List.empty();

    final LatLngBounds mapBounds;
    try {
      mapBounds = _controller!.camera.visibleBounds;
    } catch (_) {
      return List.empty();
    }

    final LatLngBounds inflatedBounds = _inflateBounds(mapBounds);

    final List<T> visibleItems = items
        .where((i) => inflatedBounds.contains(i.location))
        .toList();

    if (stopClusteringZoom != null && _zoom >= stopClusteringZoom!) {
      return visibleItems.map((i) => PlantCluster<T>.fromItems([i])).toList();
    }

    final int level = _findLevel(levels);
    return _computeClusters(
      visibleItems,
      List<PlantCluster<T>>.empty(growable: true),
      level: level,
    );
  }

  LatLngBounds _inflateBounds(LatLngBounds bounds) {
    double lng = 0;
    if (bounds.northEast.longitude < bounds.southWest.longitude) {
      lng =
          extraPercent *
          ((180.0 - bounds.southWest.longitude) +
              (bounds.northEast.longitude + 180));
    } else {
      lng =
          extraPercent *
          (bounds.northEast.longitude - bounds.southWest.longitude);
    }

    double lat =
        extraPercent * (bounds.northEast.latitude - bounds.southWest.latitude);

    double eLng = (bounds.northEast.longitude + lng).clamp(-_maxLng, _maxLng);
    double wLng = (bounds.southWest.longitude - lng).clamp(-_maxLng, _maxLng);

    final double sLat = (bounds.southWest.latitude - lat).clamp(-85.0, 85.0);
    final double nLat = (bounds.northEast.latitude + lat).clamp(-85.0, 85.0);

    return LatLngBounds(
      LatLng(sLat, wLng),
      LatLng(nLat, lng != 0 ? eLng : _maxLng),
    );
  }

  int _findLevel(List<double> levels) {
    for (int i = levels.length - 1; i >= 0; i--) {
      if (levels[i] <= _zoom) {
        return i + 1;
      }
    }
    return 1;
  }

  List<PlantCluster<T>> _computeClusters(
    List<T> inputItems,
    List<PlantCluster<T>> markerItems, {
    int level = 5,
  }) {
    if (inputItems.isEmpty) return markerItems;
    String nextGeohash = inputItems[0].geohash.substring(0, level);

    List<T> matched = inputItems
        .where((p) => p.geohash.substring(0, level) == nextGeohash)
        .toList();

    markerItems.add(PlantCluster<T>.fromItems(matched));

    List<T> remaining = List.from(
      inputItems.where((i) => i.geohash.substring(0, level) != nextGeohash),
    );

    return _computeClusters(remaining, markerItems, level: level);
  }
}
