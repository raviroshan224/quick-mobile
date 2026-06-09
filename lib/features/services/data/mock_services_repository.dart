import '../domain/service_models.dart';

class MockServicesRepository {
  static const _categories = [
    ServiceCategory(id: 'cat-1', name: 'Hair', isActive: true),
    ServiceCategory(id: 'cat-2', name: 'Nails', isActive: true),
    ServiceCategory(id: 'cat-3', name: 'Skin & Face', isActive: true),
    ServiceCategory(id: 'cat-4', name: 'Makeup', isActive: true),
    ServiceCategory(id: 'cat-5', name: 'Massage', isActive: true),
  ];

  static final _services = [
    // ── Hair ──────────────────────────────────────────────────────────────
    ServiceModel(id: 's-01', name: 'Haircut (Men)', price: 200, duration: 20, category: _categories[0], description: 'Regular scissor / clipper cut'),
    ServiceModel(id: 's-02', name: 'Haircut (Women)', price: 350, duration: 30, category: _categories[0], description: 'Trim & style with blow dry'),
    ServiceModel(id: 's-03', name: 'Kids Haircut', price: 150, duration: 15, category: _categories[0], description: 'Up to 10 years'),
    ServiceModel(id: 's-04', name: 'Hair Wash', price: 150, duration: 15, category: _categories[0], description: 'Shampoo, rinse & towel dry'),
    ServiceModel(id: 's-05', name: 'Blow Dry', price: 200, duration: 20, category: _categories[0], description: 'Wash and blow dry style'),
    ServiceModel(id: 's-06', name: 'Hair Color', price: 1500, duration: 90, category: _categories[0], description: 'Full head color with developer'),
    ServiceModel(id: 's-07', name: 'Highlights', price: 2500, duration: 120, category: _categories[0], description: 'Balayage or foil highlights'),
    ServiceModel(id: 's-08', name: 'Keratin Treatment', price: 4000, duration: 180, category: _categories[0], description: 'Smoothing keratin for frizz-free hair'),
    ServiceModel(id: 's-09', name: 'Hair Spa', price: 800, duration: 45, category: _categories[0], description: 'Deep conditioning & scalp massage'),
    ServiceModel(id: 's-10', name: 'Rebonding', price: 3500, duration: 240, category: _categories[0], description: 'Permanent hair straightening'),
    ServiceModel(id: 's-11', name: 'Beard Trim', price: 100, duration: 10, category: _categories[0]),
    ServiceModel(id: 's-12', name: 'Shave (Razor)', price: 150, duration: 15, category: _categories[0], description: 'Classic blade shave with hot towel'),
    // ── Nails ─────────────────────────────────────────────────────────────
    ServiceModel(id: 's-13', name: 'Manicure', price: 500, duration: 40, category: _categories[1], description: 'Classic manicure with polish'),
    ServiceModel(id: 's-14', name: 'Pedicure', price: 600, duration: 50, category: _categories[1], description: 'Relaxing pedicure with scrub'),
    ServiceModel(id: 's-15', name: 'Gel Nails', price: 1200, duration: 60, category: _categories[1], description: 'Long-lasting gel nail application'),
    ServiceModel(id: 's-16', name: 'Nail Art', price: 400, duration: 30, category: _categories[1], description: 'Custom nail art designs'),
    ServiceModel(id: 's-17', name: 'Nail Extension', price: 1800, duration: 90, category: _categories[1], description: 'Acrylic / gel extension set'),
    // ── Skin & Face ───────────────────────────────────────────────────────
    ServiceModel(id: 's-18', name: 'Face Wash', price: 200, duration: 15, category: _categories[2], description: 'Deep cleansing foam face wash'),
    ServiceModel(id: 's-19', name: 'Face Massage', price: 350, duration: 20, category: _categories[2], description: 'Relaxing face & neck massage'),
    ServiceModel(id: 's-20', name: 'Basic Facial', price: 800, duration: 45, category: _categories[2], description: 'Cleanse, tone & moisturise'),
    ServiceModel(id: 's-21', name: 'Gold Facial', price: 1500, duration: 60, category: _categories[2], description: 'Brightening gold-infused facial'),
    ServiceModel(id: 's-22', name: 'Anti-Acne Facial', price: 1200, duration: 60, category: _categories[2], description: 'Salicylic acid deep pore clean'),
    ServiceModel(id: 's-23', name: 'Eyebrow Threading', price: 80, duration: 10, category: _categories[2]),
    ServiceModel(id: 's-24', name: 'Eyebrow Shaping', price: 150, duration: 15, category: _categories[2], description: 'Thread + tint + define'),
    ServiceModel(id: 's-25', name: 'Upper Lip Thread', price: 50, duration: 5, category: _categories[2]),
    ServiceModel(id: 's-26', name: 'Full Face Thread', price: 200, duration: 20, category: _categories[2]),
    ServiceModel(id: 's-27', name: 'Waxing (Arms)', price: 400, duration: 25, category: _categories[2]),
    ServiceModel(id: 's-28', name: 'Waxing (Legs)', price: 600, duration: 40, category: _categories[2]),
    // ── Makeup ────────────────────────────────────────────────────────────
    ServiceModel(id: 's-29', name: 'Bridal Makeup', price: 6000, duration: 120, category: _categories[3], description: 'Complete bridal look with trial'),
    ServiceModel(id: 's-30', name: 'Party Makeup', price: 1500, duration: 60, category: _categories[3], description: 'Glamour makeup for events'),
    ServiceModel(id: 's-31', name: 'Natural Makeup', price: 800, duration: 45, category: _categories[3], description: 'Everyday fresh & light look'),
    // ── Massage ───────────────────────────────────────────────────────────
    ServiceModel(id: 's-32', name: 'Head Massage', price: 300, duration: 20, category: _categories[4]),
    ServiceModel(id: 's-33', name: 'Neck & Shoulder', price: 400, duration: 25, category: _categories[4]),
    ServiceModel(id: 's-34', name: 'Back Massage', price: 700, duration: 40, category: _categories[4]),
    ServiceModel(id: 's-35', name: 'Full Body Massage', price: 2000, duration: 90, category: _categories[4], description: 'Relaxing full-body Swedish massage'),
  ];

  Future<List<ServiceCategory>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _categories;
  }

  Future<List<ServiceModel>> getServices({String? categoryId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (categoryId == null) return _services;
    return _services.where((s) => s.category?.id == categoryId).toList();
  }

  Future<ServiceModel?> getService(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _services.firstWhere((s) => s.id == id, orElse: () => throw Exception('Not found'));
  }
}
