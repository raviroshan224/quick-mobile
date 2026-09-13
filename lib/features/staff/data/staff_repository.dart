import 'dart:math';
import 'package:uuid/uuid.dart';
import '../../../core/models/app_exception.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../domain/staff_models.dart';

const _uuid = Uuid();

class StaffRepository {
  StaffRepository(this._api);
  final ApiClient _api;

  // Staff sign in with a PIN, not a password — the account still needs one
  // internally, so generate a random one the owner never sees or shares.
  // Public so a caller that needs createWithAccount() to be safely retryable
  // (see StaffFormScreen) can generate one up front and keep sending the
  // exact same value on every retry of the same logical attempt — the
  // password is part of the /auth/register body, and the idempotency check
  // below only matches a retry whose body is byte-identical to the original.
  String generatePassword() {
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
  //
  // Step 1 alone is retry-safe: it's idempotent server-side (see
  // AuthController.register), keyed off [idempotencyKey]/[password]. If the
  // caller doesn't pass them, fresh ones are generated here — fine for a
  // one-shot call, but a caller that wants a *retry* (e.g. after a client
  // timeout where the request may have actually succeeded) must pass the
  // exact same [idempotencyKey] and [password] it used the first time, or
  // the retry becomes indistinguishable from a brand new signup attempt and
  // fails with "Email already in use" against the account step 1 already
  // created — see StaffFormScreen, which is the only caller and does this.
  // Steps 2/3 are not idempotent — a caller retrying after those partially
  // succeeded would need separate handling, not covered here.
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
    String? password,
    String? idempotencyKey,
  }) async {
    // Nobody ever sees or uses this address — staff sign in with a PIN, not
    // email — so it's just an internal identifier the backend's User model
    // requires. Kept short and readable rather than stuffing the phone
    // number into it. Only collision risk is two staff sharing a first+last
    // name, handled below by retrying once with a short disambiguator
    // rather than surfacing a confusing "email already in use" for an
    // address the owner never typed and will never see.
    final usingSyntheticEmail = email == null || email.isEmpty;
    var resolvedEmail = usingSyntheticEmail
        ? '${firstName.toLowerCase()}${lastName.toLowerCase()}@quick.staff'
        : email;

    // Step 1: create user account.
    Map<String, dynamic> userResult;
    try {
      userResult = await _api.post(
        '/auth/register',
        data: {
          'email': resolvedEmail,
          'firstName': firstName,
          'lastName': lastName,
          'password': password ?? generatePassword(),
        },
        headers: {'Idempotency-Key': idempotencyKey ?? _uuid.v4()},
      ) as Map<String, dynamic>;
    } on AppException catch (e) {
      if (!usingSyntheticEmail || !e.isConflict) rethrow;
      final suffix = (phone != null && phone.length >= 4)
          ? phone.substring(phone.length - 4)
          : _uuid.v4().substring(0, 4);
      resolvedEmail =
          '${firstName.toLowerCase()}${lastName.toLowerCase()}$suffix@quick.staff';
      // A different email is a genuinely different request — always a
      // fresh idempotency key here, never the caller's, so the backend
      // can't mistake this for a retry of the first (failed) attempt.
      userResult = await _api.post(
        '/auth/register',
        data: {
          'email': resolvedEmail,
          'firstName': firstName,
          'lastName': lastName,
          'password': password ?? generatePassword(),
        },
        headers: {'Idempotency-Key': _uuid.v4()},
      ) as Map<String, dynamic>;
    }

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
      // These are sent as an explicit key even when null (not omitted) —
      // the only caller (staff_form_screen._saveEdit) always submits the
      // form's full current state, so a field the user cleared must
      // actually clear on the backend rather than silently keeping its old
      // value (an omitted key means "leave unchanged" in this PATCH).
      'phone': phone,
      'specialties': ?specialties,
      'commissionRate': commissionRate,
      'isActive': ?isActive,
      'emergencyContact': emergencyContact,
      'emergencyContactName': emergencyContactName,
      'emergencyRelationship': emergencyRelationship,
      'address': address,
    }) as Map<String, dynamic>;
    return StaffModel.fromJson(data);
  }

  Future<void> delete(String id) => _api.delete('/staff/$id');
}
