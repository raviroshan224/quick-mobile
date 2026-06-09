import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/customer_model.dart';

class CustomersNotifier extends StateNotifier<List<Customer>> {
  CustomersNotifier() : super(_mockCustomers);

  void add(Customer c) => state = [...state, c];

  void update(Customer c) {
    state = [for (final s in state) if (s.id == c.id) c else s];
  }

  void delete(String id) =>
      state = state.where((c) => c.id != id).toList();

  void updateNotes(String id, String notes) {
    state = [
      for (final c in state)
        if (c.id == id) c.copyWith(notes: notes.trim().isEmpty ? null : notes)
        else c,
    ];
  }
}

final customersProvider =
    StateNotifierProvider<CustomersNotifier, List<Customer>>(
  (_) => CustomersNotifier(),
);

/// Customer attached to the active checkout. Cleared on "New Sale".
final checkoutCustomerProvider = StateProvider<Customer?>((ref) => null);

/// Mock visit history keyed by customer id.
final Map<String, List<VisitRecord>> mockVisitHistory = {
  '1': [
    VisitRecord(
      id: 'v1',
      date: DateTime(2026, 6, 3),
      services: ['Haircut & Blow Dry'],
      total: 800,
    ),
    VisitRecord(
      id: 'v2',
      date: DateTime(2026, 5, 15),
      services: ['Hair Color (Full)', 'Classic Facial'],
      total: 3700,
    ),
    VisitRecord(
      id: 'v3',
      date: DateTime(2026, 4, 20),
      services: ['Haircut & Blow Dry', 'Keratin Shampoo'],
      total: 1250,
    ),
  ],
  '2': [
    VisitRecord(
      id: 'v4',
      date: DateTime(2026, 6, 1),
      services: ['Manicure', 'Pedicure'],
      total: 1300,
    ),
    VisitRecord(
      id: 'v5',
      date: DateTime(2026, 5, 5),
      services: ['Classic Facial'],
      total: 1200,
    ),
  ],
  '3': [
    VisitRecord(
      id: 'v6',
      date: DateTime(2026, 5, 28),
      services: ['Swedish Massage (60 min)'],
      total: 1800,
    ),
  ],
};

final _mockCustomers = [
  Customer(
    id: '1',
    name: 'Priya Sharma',
    phone: '9841123456',
    birthday: DateTime(1992, 3, 15),
    notes: 'Prefers keratin treatment. Sensitive to ammonia-based color.',
    visitCount: 12,
    totalSpend: 18400,
    lastVisitDate: DateTime(2026, 6, 3),
  ),
  Customer(
    id: '2',
    name: 'Anita Gurung',
    phone: '9812345678',
    birthday: DateTime(1988, 11, 4),
    notes: 'Loves gel nails — shade: coral pink.',
    visitCount: 8,
    totalSpend: 9600,
    lastVisitDate: DateTime(2026, 6, 1),
  ),
  Customer(
    id: '3',
    name: 'Suman Thapa',
    phone: '9823456789',
    visitCount: 3,
    totalSpend: 5400,
    lastVisitDate: DateTime(2026, 5, 28),
  ),
  Customer(
    id: '4',
    name: 'Kiran Rai',
    phone: '9856789012',
    notes: 'Regulars — always books on Saturdays.',
    visitCount: 22,
    totalSpend: 33000,
    lastVisitDate: DateTime(2026, 5, 20),
  ),
  Customer(
    id: '5',
    name: 'Bimala Karki',
    phone: '9867890123',
    birthday: DateTime(1995, 7, 22),
    visitCount: 1,
    totalSpend: 800,
    lastVisitDate: DateTime(2026, 4, 10),
  ),
  Customer(
    id: '6',
    name: 'Ramesh Shrestha',
    phone: '9878901234',
    visitCount: 5,
    totalSpend: 7500,
    lastVisitDate: DateTime(2026, 3, 5),
  ),
];
