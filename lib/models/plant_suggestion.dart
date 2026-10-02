class PlantSuggestion {
  final String plantId;
  final String scientificName;
  final String commonName;
  final String? imageUrl;

  PlantSuggestion({
    required this.plantId,
    required this.scientificName,
    required this.commonName,
    this.imageUrl,
  });

  factory PlantSuggestion.fromJson(Map<String, dynamic> json) {
    return PlantSuggestion(
      plantId: json['plant_id']?.toString() ?? '',
      scientificName: json['scientific_name']?.toString() ?? '',
      commonName: json['common_name']?.toString() ?? 'Không xác định',
      imageUrl: json['image_url']?.toString(),
    );
  }
}
