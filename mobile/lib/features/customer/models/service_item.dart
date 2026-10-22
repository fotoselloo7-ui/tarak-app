class ServiceItem {
  final int id;
  final String name;
  final String? slug;
  final String? iconClass;
  final int? durationMinutes;
  final String? categoryId;
  final bool isActive;

  const ServiceItem({
    required this.id,
    required this.name,
    this.slug,
    this.iconClass,
    this.durationMinutes,
    this.categoryId,
    this.isActive = true,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString(),
      iconClass: json['icon_class']?.toString(),
      durationMinutes: json['duration_minutes'] is int
          ? json['duration_minutes'] as int
          : int.tryParse(json['duration_minutes'].toString()),
      categoryId: json['category_id']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
