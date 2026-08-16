class ServiceCategory {
  const ServiceCategory({required this.id, required this.name, required this.isActive});
  final String id;
  final String name;
  final bool isActive;

  factory ServiceCategory.fromJson(Map<String, dynamic> j) => ServiceCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        isActive: j['isActive'] as bool? ?? true,
      );

  // Local-only round-trip (session persistence — see SalonSessionsStorage),
  // not sent to the backend, which never accepts a category shape like this.
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'isActive': isActive};

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
    this.color,
    this.isActive = true,
  });

  final String id;
  final String name;
  final double price; // 0 means not set — only name is required to create a service
  final int duration; // minutes; 0 means not set
  final String? description;
  final ServiceCategory? category;
  final String? iconUrl;
  // Owner-chosen checkout card color key (e.g. "coral") — one of
  // kServiceColorPalette's keys, see service_colors.dart. Null means "auto":
  // the checkout card color is derived deterministically from the service's
  // category/id instead.
  final String? color;
  final bool isActive;

  factory ServiceModel.fromJson(Map<String, dynamic> j) {
    final cat = j['category'] as Map<String, dynamic>?;
    return ServiceModel(
      id: j['id'] as String,
      name: j['name'] as String,
      price: (j['price'] as num? ?? 0).toDouble(),
      duration: j['duration'] as int? ?? 0,
      description: j['description'] as String?,
      category: cat != null ? ServiceCategory.fromJson(cat) : null,
      iconUrl: j['iconUrl'] as String?,
      color: j['color'] as String?,
      isActive: j['isActive'] as bool? ?? true,
    );
  }

  // Local-only round-trip (session persistence), not sent to the backend.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'duration': duration,
        'description': description,
        'category': category?.toJson(),
        'iconUrl': iconUrl,
        'color': color,
        'isActive': isActive,
      };

  String get durationLabel {
    if (duration <= 0) return '';
    return duration >= 60
        ? '${duration ~/ 60}h ${duration % 60 > 0 ? '${duration % 60}m' : ''}'
        : '${duration}m';
  }
  String get priceLabel => 'Rs ${price.toStringAsFixed(0)}';

  ServiceModel copyWith({
    String? name, double? price, int? duration,
    String? description, ServiceCategory? category, String? iconUrl,
    String? color, bool clearColor = false, bool? isActive,
  }) => ServiceModel(
        id: id, name: name ?? this.name, price: price ?? this.price,
        duration: duration ?? this.duration, description: description ?? this.description,
        category: category ?? this.category, iconUrl: iconUrl ?? this.iconUrl,
        color: clearColor ? null : (color ?? this.color),
        isActive: isActive ?? this.isActive,
      );
}
