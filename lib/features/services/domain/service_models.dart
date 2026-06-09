class ServiceCategory {
  const ServiceCategory({required this.id, required this.name, required this.isActive});
  final String id;
  final String name;
  final bool isActive;

  ServiceCategory copyWith({String? name, bool? isActive}) =>
      ServiceCategory(id: id, name: name ?? this.name, isActive: isActive ?? this.isActive);
}

class ServiceModel {
  const ServiceModel({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    this.description,
    this.category,
    this.iconUrl,
    this.isActive = true,
  });

  final String id;
  final String name;
  final double price;
  final int duration; // minutes
  final String? description;
  final ServiceCategory? category;
  final String? iconUrl;
  final bool isActive;

  String get durationLabel => duration >= 60 ? '${duration ~/ 60}h ${duration % 60 > 0 ? '${duration % 60}m' : ''}' : '${duration}m';
  String get priceLabel => 'NPR ${price.toStringAsFixed(0)}';

  ServiceModel copyWith({
    String? name, double? price, int? duration,
    String? description, ServiceCategory? category, String? iconUrl, bool? isActive,
  }) => ServiceModel(
        id: id, name: name ?? this.name, price: price ?? this.price,
        duration: duration ?? this.duration, description: description ?? this.description,
        category: category ?? this.category, iconUrl: iconUrl ?? this.iconUrl,
        isActive: isActive ?? this.isActive,
      );
}
