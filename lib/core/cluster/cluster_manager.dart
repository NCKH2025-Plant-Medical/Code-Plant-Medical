// lib/core/cluster/cluster_manager.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart'
    hide Cluster, ClusterManager;
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

  final Future<Marker> Function(PlantCluster<T>) markerBuilder;
  final void Function(Set<Marker>) updateMarkers;
  final List<double> levels;
  final double extraPercent;
  final double? stopClusteringZoom;

  static final int precision = kIsWeb ? 12 : 20;

  GoogleMapController? _controller;
  Iterable<T> get items => _items;
  Iterable<T> _items;
  double _zoom = 15.0;

  final double _maxLng = 180 - pow(10, -10.0) as double;

  void setMapController(GoogleMapController controller, {bool withUpdate = true}) async {
    _controller = controller;
    _zoom = await controller.getZoomLevel();
    if (withUpdate) updateMap();
  }

  void updateMap() {
    _updateClusters();
  }

  void _updateClusters() async {
    List<PlantCluster<T>> mapMarkers = await getMarkers();
    final Set<Marker> markers =
        Set.from(await Future.wait(mapMarkers.map((m) => markerBuilder(m))));
    updateMarkers(markers);
  }

  void setItems(List<T> newItems) {
    _items = newItems;
    updateMap();
  }

  void onCameraMove(CameraPosition position, {bool forceUpdate = false}) {
    _zoom = position.zoom;
    if (forceUpdate) {
      updateMap();
    }
  }

  Future<List<PlantCluster<T>>> getMarkers() async {
    if (_controller == null) return List.empty();

    final LatLngBounds mapBounds = await _controller!.getVisibleRegion();
    final LatLngBounds inflatedBounds = _inflateBounds(mapBounds);

    List<T> visibleItems = items.where((i) {
      return inflatedBounds.contains(i.location);
    }).toList();

    if (stopClusteringZoom != null && _zoom >= stopClusteringZoom!) {
      return visibleItems.map((i) => PlantCluster<T>.fromItems([i])).toList();
    }

    int level = _findLevel(levels);
    return _computeClusters(visibleItems, List.empty(growable: true), level: level);
  }

  LatLngBounds _inflateBounds(LatLngBounds bounds) {
    double lng = 0;
    if (bounds.northeast.longitude < bounds.southwest.longitude) {
      lng = extraPercent *
          ((180.0 - bounds.southwest.longitude) +
              (bounds.northeast.longitude + 180));
    } else {
      lng = extraPercent *
          (bounds.northeast.longitude - bounds.southwest.longitude);
    }

    double lat =
        extraPercent * (bounds.northeast.latitude - bounds.southwest.latitude);

    double eLng = (bounds.northeast.longitude + lng).clamp(-_maxLng, _maxLng);
    double wLng = (bounds.southwest.longitude - lng).clamp(-_maxLng, _maxLng);

    return LatLngBounds(
      southwest: LatLng(bounds.southwest.latitude - lat, wLng),
      northeast: LatLng(bounds.northeast.latitude + lat, lng != 0 ? eLng : _maxLng),
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
      List<T> inputItems, List<PlantCluster<T>> markerItems,
      {int level = 5}) {
    if (inputItems.isEmpty) return markerItems;
    String nextGeohash = inputItems[0].geohash.substring(0, level);

    List<T> matched = inputItems
        .where((p) => p.geohash.substring(0, level) == nextGeohash)
        .toList();

    markerItems.add(PlantCluster<T>.fromItems(matched));

    List<T> remaining = List.from(
        inputItems.where((i) => i.geohash.substring(0, level) != nextGeohash));

    return _computeClusters(remaining, markerItems, level: level);
  }
}
