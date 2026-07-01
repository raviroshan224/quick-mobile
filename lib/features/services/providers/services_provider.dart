import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/service_model.dart';

class ServicesNotifier extends StateNotifier<List<Service>> {
  ServicesNotifier() : super(_mockServices);

  void add(Service service) => state = [...state, service];

  void update(Service service) {
    state = [for (final s in state) if (s.id == service.id) service else s];
  }

  void delete(String id) => state = state.where((s) => s.id != id).toList();

  void toggleTop(String id) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(isTopService: !s.isTopService) else s,
    ];
  }
}

final servicesProvider =
    StateNotifierProvider<ServicesNotifier, List<Service>>(
  (_) => ServicesNotifier(),
);

final _mockServices = [
  const Service(
    id: '1',
    name: 'Haircut & Blow Dry',
    price: 800,
    durationMinutes: 45,
    category: 'Hair',
    description: 'Includes shampoo, cut, and blow dry finish.',
    isActive: true,
    isTopService: true,
  ),
  const Service(
    id: '2',
    name: 'Hair Color (Full)',
    price: 2500,
    durationMinutes: 120,
    category: 'Color',
    description: 'Full head color with professional dye.',
    isActive: true,
    isTopService: true,
  ),
  const Service(
    id: '3',
    name: 'Classic Facial',
    price: 1200,
    durationMinutes: 60,
    category: 'Facial',
    isActive: true,
    isTopService: false,
  ),
  const Service(
    id: '4',
    name: 'Swedish Massage (60 min)',
    price: 1800,
    durationMinutes: 60,
    category: 'Massage',
    isActive: true,
    isTopService: true,
  ),
  const Service(
    id: '5',
    name: 'Manicure',
    price: 600,
    durationMinutes: 30,
    category: 'Nails',
    isActive: true,
    isTopService: false,
  ),
  const Service(
    id: '6',
    name: 'Pedicure',
    price: 700,
    durationMinutes: 40,
    category: 'Nails',
    isActive: true,
    isTopService: false,
  ),
  const Service(
    id: '7',
    name: 'Full Leg Wax',
    price: 900,
    durationMinutes: 45,
    category: 'Wax',
    isActive: true,
    isTopService: false,
  ),
  const Service(
    id: '8',
    name: 'Highlights (Partial)',
    price: 1600,
    durationMinutes: 90,
    category: 'Color',
    isActive: false,
    isTopService: false,
  ),
];
