import 'dart:math';
import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../domain/staff_models.dart';

class StaffRepository {
  StaffRepository(this._api);
  final ApiClient _api;

  // Staff sign in with a PIN, not a password — the account still needs one
  // internally, so generate a random one the owner never sees or shares.
  String _generatePassword() {
    final rand = Random.secure();
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const digits = '23456789';
    final chars = List.generate(12, (i) {
      final pool = switch (i % 3) { 0 => upper, 1 => lower, _ => digits };
      return pool[rand.nextInt(pool.length)];
    })..shuffle(rand);
    return chars.join();
  }

  Future<List<StaffModel>> getAll({bool activeOnly = false}) async {
    final data = await _api.get('/staff', queryParameters: {
      'limit': 100,
      if (activeOnly) 'isActive': true,
    }) as Map<String, dynamic>;
    return PaginatedResponse.fromJson(data, StaffModel.fromJson).data;
  }

  Future<StaffModel> getById(String id) async {
    final data = await _api.get('/staff/$id') as Map<String, dynamic>;
    return StaffModel.fromJson(data);
  }

  // Creates a staff account and profile in three steps:
  // 1. POST /auth/register → creates the User account (random password;
  //    staff sign in with their PIN, not this)
  // 2. POST /staff → creates the Staff profile linked to that user
  // 3. PATCH /auth/staff/:id/pin → sets the sign-in PIN
  Future<({StaffModel staff, String email})> createWithAccount({
    required String firstName,
    required String lastName,
    required String pin,
    String? email,
    String? phone,
    List<String> specialties = const [],
    double? commissionRate,
    bool isActive = true,
    String? emergencyContact,
    String? emergencyContactName,
    String? emergencyRelationship,
    String? address,
    String? govIdType,
  }) async {
    final resolvedEmail = (email != null && email.isNotEmpty)
        ? email
        : '${firstName.toLowerCase()}${lastName.toLowerCase()}$phone@quickpos.staff';

    // Step 1: create user account.
    final userResult = await _api.post('/auth/register', data: {
      'email': resolvedEmail,
      'firstName': firstName,
      'lastName': lastName,
      'password': _generatePassword(),
    }) as Map<String, dynamic>;

    final userId = (userResult['user'] as Map<String, dynamic>?)?['id'] as String? ??
        userResult['id'] as String? ??
        '';

    // Step 2: create staff profile.
    final staffData = await _api.post('/staff', data: {
      'userId': userId,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'specialties': specialties,
      'commissionRate': ?commissionRate,
      'emergencyContact': ?emergencyContact,
      'emergencyContactName': ?emergencyContactName,
      'emergencyRelationship': ?emergencyRelationship,
      'address': ?address,
      'govIdType': ?govIdType,
    }) as Map<String, dynamic>;

    final staff = StaffModel.fromJson(staffData);

    // Step 3: set the sign-in PIN.
    await _api.patch('/auth/staff/${staff.id}/pin', data: {'pin': pin});

    return (staff: staff, email: resolvedEmail);
  }

  Future<StaffModel> update(
    String id, {
    String? phone,
    List<String>? specialties,
    double? commissionRate,
    bool? isActive,
    String? emergencyContact,
    String? emergencyContactName,
    String? emergencyRelationship,
    String? address,
  }) async {
    final data = await _api.patch('/staff/$id', data: {
      'phone': ?phone,
      'specialties': ?specialties,
      'commissionRate': ?commissionRate,
      'isActive': ?isActive,
      'emergencyContact': ?emergencyContact,
      'emergencyContactName': ?emergencyContactName,
      'emergencyRelationship': ?emergencyRelationship,
      'address': ?address,
    }) as Map<String, dynamic>;
    return StaffModel.fromJson(data);
  }

  Future<void> delete(String id) => _api.delete('/staff/$id');
}
