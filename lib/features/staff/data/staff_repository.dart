import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../domain/staff_models.dart';

class StaffRepository {
  StaffRepository(this._api);
  final ApiClient _api;

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

  // Creates a staff account and profile in two steps:
  // 1. POST /auth/register → creates the User account
  // 2. POST /staff → creates the Staff profile linked to that user
  Future<({StaffModel staff, String email, String password})> createWithAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
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
    // Step 1: create user account.
    final userResult = await _api.post('/auth/register', data: {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'password': password,
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

    return (
      staff: StaffModel.fromJson(staffData),
      email: email,
      password: password,
    );
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
