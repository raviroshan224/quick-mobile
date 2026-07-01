import 'package:uuid/uuid.dart';

const _uuid = Uuid();

const List<String> serviceCategories = [
  'All',
  'Hair',
  'Color',
  'Facial',
  'Spa',
  'Nails',
  'Massage',
  'Wax',
  'Other',
];

class Service {
  final String id;
  final String name;
  final double price;
  final int durationMinutes;
  final String category;
  final String? description;
  final bool isActive;
  final bool isTopService;

  const Service({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.category,
    this.description,
    this.isActive = true,
    this.isTopService = false,
  });

  String get durationLabel {
    if (durationMinutes < 60) return '${durationMinutes}m';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  Service copyWith({
    String? name,
    double? price,
    int? durationMinutes,
    String? category,
    String? description,
    bool? isActive,
    bool? isTopService,
  }) {
    return Service(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      category: category ?? this.category,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      isTopService: isTopService ?? this.isTopService,
    );
  }

  static Service create({
    required String name,
    required double price,
    required int durationMinutes,
    required String category,
    String? description,
    bool isActive = true,
    bool isTopService = false,
  }) {
    return Service(
      id: _uuid.v4(),
      name: name,
      price: price,
      durationMinutes: durationMinutes,
      category: category,
      description: description,
      isActive: isActive,
      isTopService: isTopService,
    );
  }
}
