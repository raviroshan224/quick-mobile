import '../domain/staff_models.dart';

class MockStaffRepository {
  static final _staff = [
    const StaffModel(
      id: 'st-01', userId: 'u-st-01',
      firstName: 'Priya', lastName: 'Thapa',
      phone: '9841001001',
      specialties: ['Haircut', 'Hair Color', 'Blow Dry'],
      commissionRate: 15,
      isActive: true,
    ),
    const StaffModel(
      id: 'st-02', userId: 'u-st-02',
      firstName: 'Rina', lastName: 'Shrestha',
      phone: '9841002002',
      specialties: ['Manicure', 'Pedicure', 'Nail Art', 'Gel Nails'],
      commissionRate: 12,
      isActive: true,
    ),
    const StaffModel(
      id: 'st-03', userId: 'u-st-03',
      firstName: 'Sita', lastName: 'Gurung',
      phone: '9841003003',
      specialties: ['Facial', 'Eyebrow Threading', 'Waxing', 'Skin Care'],
      commissionRate: 10,
      isActive: true,
    ),
    const StaffModel(
      id: 'st-04', userId: 'u-st-04',
      firstName: 'Anil', lastName: 'Rai',
      phone: '9841004004',
      specialties: ['Haircut', 'Beard Trim', 'Keratin Treatment'],
      commissionRate: 15,
      isActive: true,
    ),
    const StaffModel(
      id: 'st-05', userId: 'u-st-05',
      firstName: 'Maya', lastName: 'Tamang',
      phone: '9841005005',
      specialties: ['Bridal Makeup', 'Party Makeup', 'Hair Color'],
      commissionRate: 20,
      isActive: false,
    ),
  ];

  Future<List<StaffModel>> getAll({bool activeOnly = false}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return activeOnly ? _staff.where((s) => s.isActive).toList() : _staff;
  }

  Future<StaffModel> getById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _staff.firstWhere((s) => s.id == id, orElse: () => throw Exception('Staff not found'));
  }
}
