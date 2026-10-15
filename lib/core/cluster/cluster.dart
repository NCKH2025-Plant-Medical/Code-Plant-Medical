// lib/core/cluster/cluster.dart
import 'package:google_maps_flutter/google_maps_flutter.dart'
    hide Cluster, ClusterManager;
import 'cluster_item.dart';

class PlantCluster<T extends ClusterItem> {
  final LatLng location;
  final Iterable<T> items;

  PlantCluster(this.items, this.location);

  PlantCluster.fromItems(this.items)
      : location = LatLng(
          items.isEmpty
              ? 0.0
              : items.fold<double>(0.0, (p, c) => p + c.location.latitude) /
                  items.length,
          items.isEmpty
              ? 0.0
              : items.fold<double>(0.0, (p, c) => p + c.location.longitude) /
                  items.length,
        );

  PlantCluster.fromClusters(PlantCluster<T> cluster1, PlantCluster<T> cluster2)
      : items = cluster1.items.toSet()..addAll(cluster2.items.toSet()),
        location = LatLng(
          (cluster1.location.latitude * cluster1.count +
                  cluster2.location.latitude * cluster2.count) /
              (cluster1.count + cluster2.count),
          (cluster1.location.longitude * cluster1.count +
                  cluster2.location.longitude * cluster2.count) /
              (cluster1.count + cluster2.count),
        );

  int get count => items.length;

  bool get isMultiple => items.length > 1;

  String getId() {
    return '${location.latitude}_${location.longitude}_$count';
  }

  @override
  String toString() {
    return 'PlantCluster of $count $T (${location.latitude}, ${location.longitude})';
  }

  @override
  bool operator ==(Object other) => other is PlantCluster && items == other.items;

  @override
  int get hashCode => items.hashCode;
}
