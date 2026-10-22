class ServiceCategory {
  final String id;
  final String name;
  final String? slug;

  /// Domain provider type ('barber' | 'coiffeur'). Drives per-category visuals
  /// on the homepage so nothing has to be keyed off hardcoded category names.
  final String? providerType;

  const ServiceCategory({
    required this.id,
    required this.name,
    this.slug,
    this.providerType,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      providerType: json['provider_type']?.toString(),
    );
  }
}
