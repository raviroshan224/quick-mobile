import '../../../core/network/api_client.dart';
import '../domain/cash_drawer_models.dart';

class CashDrawerRepository {
  CashDrawerRepository(this._api);
  final ApiClient _api;

  Future<CashDrawerSession?> getCurrent() async {
    try {
      final data = await _api.get('/cash-drawer/current') as Map<String, dynamic>;
      return _sessionFromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<CashDrawerSession> open(double openBalance, {String? notes}) async {
    final data = await _api.post('/cash-drawer/open', data: {
      'openBalance': openBalance,
      'notes': ?notes,
    }) as Map<String, dynamic>;
    return _sessionFromJson(data);
  }

  Future<CashDrawerSession> close(double closeBalance, {String? notes}) async {
    final data = await _api.post('/cash-drawer/close', data: {
      'closeBalance': closeBalance,
      'notes': ?notes,
    }) as Map<String, dynamic>;
    return _sessionFromJson(data);
  }

  Future<void> recordMovement({
    required CashMovementType type,
    required double amount,
    required String reason,
  }) async {
    await _api.post('/cash-drawer/movement', data: {
      'type': type == CashMovementType.cashIn ? 'IN' : 'OUT',
      'amount': amount,
      'reason': reason,
    });
  }

  static CashDrawerSession _sessionFromJson(Map<String, dynamic> j) {
    final raw = j['cashDrawer'] as Map<String, dynamic>? ?? j;
    final movements = (raw['cashMovements'] as List<dynamic>? ?? [])
        .map((m) => _movementFromJson(m as Map<String, dynamic>))
        .toList();
    return CashDrawerSession(
      id: raw['id'] as String,
      openBalance: (raw['openBalance'] as num).toDouble(),
      openedAt: DateTime.parse(raw['openedAt'] as String),
      movements: movements,
      closeBalance: (raw['closeBalance'] as num?)?.toDouble(),
      closedAt: raw['closedAt'] != null ? DateTime.parse(raw['closedAt'] as String) : null,
      notes: raw['notes'] as String?,
    );
  }

  static CashMovementEntry _movementFromJson(Map<String, dynamic> j) {
    final typeStr = j['type'] as String? ?? 'IN';
    return CashMovementEntry(
      id: j['id'] as String,
      type: typeStr == 'IN' ? CashMovementType.cashIn : CashMovementType.cashOut,
      amount: (j['amount'] as num).toDouble(),
      reason: j['reason'] as String? ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String),
      transactionId: j['transactionId'] as String?,
    );
  }
}
