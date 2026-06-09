import '../domain/customer_models.dart';

class MockCustomersRepository {
  static final _customers = [
    CustomerModel(id: 'c-01', firstName: 'Anita', lastName: 'Paudel', phone: '9801001001', email: 'anita@email.com', visitCount: 12, totalSpent: 28400, lastVisitDate: DateTime.now().subtract(const Duration(days: 3)), notes: 'Prefers herbal treatments'),
    CustomerModel(id: 'c-02', firstName: 'Kamala', lastName: 'Bhattarai', phone: '9801002002', visitCount: 5, totalSpent: 9800, lastVisitDate: DateTime.now().subtract(const Duration(days: 10))),
    CustomerModel(id: 'c-03', firstName: 'Sunita', lastName: 'KC', phone: '9801003003', email: 'sunita@email.com', visitCount: 28, totalSpent: 64200, lastVisitDate: DateTime.now().subtract(const Duration(days: 1)), notes: 'VIP client — bridal next month'),
    CustomerModel(id: 'c-04', firstName: 'Ramesh', lastName: 'Adhikari', phone: '9801004004', visitCount: 8, totalSpent: 12600, lastVisitDate: DateTime.now().subtract(const Duration(days: 7))),
    CustomerModel(id: 'c-05', firstName: 'Bina', lastName: 'Maharjan', phone: '9801005005', email: 'bina@email.com', visitCount: 3, totalSpent: 5400, lastVisitDate: DateTime.now().subtract(const Duration(days: 21))),
    CustomerModel(id: 'c-06', firstName: 'Geeta', lastName: 'Koirala', phone: '9801006006', visitCount: 15, totalSpent: 38500, lastVisitDate: DateTime.now()),
    CustomerModel(id: 'c-07', firstName: 'Dipika', lastName: 'Rana', phone: '9801007007', visitCount: 0, totalSpent: 0),
    CustomerModel(id: 'c-08', firstName: 'Sabina', lastName: 'Magar', phone: '9801008008', visitCount: 6, totalSpent: 14800, lastVisitDate: DateTime.now().subtract(const Duration(days: 14))),
  ];

  Future<List<CustomerModel>> getAll({String? query}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (query == null || query.trim().isEmpty) return _customers;
    final q = query.toLowerCase();
    return _customers.where((c) =>
        c.fullName.toLowerCase().contains(q) ||
        (c.phone?.contains(q) ?? false) ||
        (c.email?.toLowerCase().contains(q) ?? false)).toList();
  }

  Future<CustomerModel?> getById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try { return _customers.firstWhere((c) => c.id == id); } catch (_) { return null; }
  }
}
