import '../domain/cash_drawer_models.dart';

class MockCashDrawerRepository {
  static final _session = CashDrawerSession(
    id: 'drawer-01',
    openBalance: 5000,
    openedAt: DateTime.now().subtract(const Duration(hours: 6)),
    movements: [
      CashMovementEntry(id: 'm-01', type: CashMovementType.cashIn, amount: 800, reason: 'Haircut — Priya', createdAt: DateTime.now().subtract(const Duration(hours: 5, minutes: 30))),
      CashMovementEntry(id: 'm-02', type: CashMovementType.cashIn, amount: 3500, reason: 'Hair Color — Anil', createdAt: DateTime.now().subtract(const Duration(hours: 4))),
      CashMovementEntry(id: 'm-03', type: CashMovementType.cashOut, amount: 200, reason: 'Tea & snacks for staff', createdAt: DateTime.now().subtract(const Duration(hours: 3))),
      CashMovementEntry(id: 'm-04', type: CashMovementType.cashIn, amount: 2500, reason: 'Facial — Sita', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
      CashMovementEntry(id: 'm-05', type: CashMovementType.cashIn, amount: 700, reason: 'Manicure — Rina', createdAt: DateTime.now().subtract(const Duration(hours: 1))),
      CashMovementEntry(id: 'm-06', type: CashMovementType.cashOut, amount: 500, reason: 'Supplier payment — cotton rolls', createdAt: DateTime.now().subtract(const Duration(minutes: 30))),
    ],
  );

  Future<CashDrawerSession?> getCurrent() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _session;
  }
}
