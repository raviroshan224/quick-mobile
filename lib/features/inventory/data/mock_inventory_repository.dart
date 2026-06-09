import '../domain/inventory_models.dart';

class MockInventoryRepository {
  static final _products = [
    // ── Shampoos ──────────────────────────────────────────────────────────
    const ProductModel(id: 'p-01', name: 'Loreal Shampoo 500ml', sku: 'LS-001', price: 680, cost: 400, stock: 12, lowStockThreshold: 5, category: 'Shampoo', description: 'Smooth & Silky for all hair types'),
    const ProductModel(id: 'p-02', name: 'Pantene Shampoo 200ml', sku: 'PS-001', price: 280, cost: 160, stock: 20, lowStockThreshold: 8, category: 'Shampoo', description: 'Pro-V nourishing formula'),
    const ProductModel(id: 'p-03', name: 'Dove Shampoo 340ml', sku: 'DS-001', price: 350, cost: 210, stock: 18, lowStockThreshold: 8, category: 'Shampoo'),
    const ProductModel(id: 'p-04', name: 'Head & Shoulders 400ml', sku: 'HNS-001', price: 420, cost: 250, stock: 9, lowStockThreshold: 5, category: 'Shampoo', description: 'Anti-dandruff formula'),
    // ── Conditioners ──────────────────────────────────────────────────────
    const ProductModel(id: 'p-05', name: 'Loreal Conditioner 500ml', sku: 'LC-001', price: 720, cost: 430, stock: 10, lowStockThreshold: 5, category: 'Conditioner'),
    const ProductModel(id: 'p-06', name: 'Pantene Conditioner 200ml', sku: 'PC-001', price: 290, cost: 170, stock: 15, lowStockThreshold: 5, category: 'Conditioner'),
    // ── Scissors & Cutting Tools ──────────────────────────────────────────
    const ProductModel(id: 'p-07', name: 'Cutting Scissors 6"', sku: 'CS-001', price: 1200, cost: 700, stock: 8, lowStockThreshold: 3, category: 'Scissors', description: 'Stainless steel professional scissors'),
    const ProductModel(id: 'p-08', name: 'Thinning Scissors', sku: 'TS-001', price: 950, cost: 550, stock: 5, lowStockThreshold: 2, category: 'Scissors', description: 'Texturizing / thinning shears'),
    const ProductModel(id: 'p-09', name: 'Eyebrow Scissors', sku: 'ES-001', price: 350, cost: 180, stock: 12, lowStockThreshold: 4, category: 'Scissors'),
    // ── Combs & Brushes ───────────────────────────────────────────────────
    const ProductModel(id: 'p-10', name: 'Wide-Tooth Comb', sku: 'WC-001', price: 80, cost: 40, stock: 30, lowStockThreshold: 10, category: 'Combs'),
    const ProductModel(id: 'p-11', name: 'Tail Comb', sku: 'TC-001', price: 60, cost: 30, stock: 25, lowStockThreshold: 10, category: 'Combs'),
    const ProductModel(id: 'p-12', name: 'Detangling Comb', sku: 'DC-001', price: 90, cost: 45, stock: 20, lowStockThreshold: 8, category: 'Combs'),
    const ProductModel(id: 'p-13', name: 'Round Brush', sku: 'RB-001', price: 250, cost: 140, stock: 14, lowStockThreshold: 5, category: 'Combs'),
    const ProductModel(id: 'p-14', name: 'Paddle Brush', sku: 'PB-001', price: 320, cost: 180, stock: 10, lowStockThreshold: 4, category: 'Combs'),
    const ProductModel(id: 'p-15', name: 'Hair Clips (Pack 12)', sku: 'HC-001', price: 120, cost: 60, stock: 40, lowStockThreshold: 10, category: 'Combs'),
    // ── Blades & Razors ───────────────────────────────────────────────────
    const ProductModel(id: 'p-16', name: 'Safety Razor Blade (10 pcs)', sku: 'SB-001', price: 50, cost: 25, stock: 100, lowStockThreshold: 20, category: 'Blades', description: 'Double-edged stainless blades'),
    const ProductModel(id: 'p-17', name: 'Disposable Razor (Pack 5)', sku: 'DR-001', price: 80, cost: 40, stock: 60, lowStockThreshold: 15, category: 'Blades'),
    const ProductModel(id: 'p-18', name: 'Barber Straight Razor', sku: 'BR-001', price: 850, cost: 500, stock: 4, lowStockThreshold: 2, category: 'Blades', description: 'Stainless folding straight razor'),
    const ProductModel(id: 'p-19', name: 'Eyebrow Razor', sku: 'ER-001', price: 60, cost: 30, stock: 50, lowStockThreshold: 15, category: 'Blades'),
    // ── Hair Color ────────────────────────────────────────────────────────
    const ProductModel(id: 'p-20', name: 'Wella Color 60ml', sku: 'WC-002', price: 450, cost: 280, stock: 24, lowStockThreshold: 10, category: 'Hair Color'),
    const ProductModel(id: 'p-21', name: 'Garnier Color 40ml', sku: 'GC-001', price: 320, cost: 190, stock: 30, lowStockThreshold: 10, category: 'Hair Color'),
    const ProductModel(id: 'p-22', name: 'Color Developer 6%', sku: 'CD-001', price: 280, cost: 150, stock: 15, lowStockThreshold: 5, category: 'Hair Color'),
    // ── Treatments & Serums ───────────────────────────────────────────────
    const ProductModel(id: 'p-23', name: 'Keratin Treatment 250ml', sku: 'KT-001', price: 2200, cost: 1400, stock: 7, lowStockThreshold: 3, category: 'Treatment'),
    const ProductModel(id: 'p-24', name: 'Hair Serum 50ml', sku: 'HS-001', price: 1200, cost: 700, stock: 11, lowStockThreshold: 4, category: 'Treatment'),
    const ProductModel(id: 'p-25', name: 'Hair Mask 200ml', sku: 'HM-001', price: 680, cost: 380, stock: 9, lowStockThreshold: 4, category: 'Treatment'),
    // ── Skin Care ─────────────────────────────────────────────────────────
    const ProductModel(id: 'p-26', name: 'Face Wash Foam 100ml', sku: 'FW-001', price: 380, cost: 200, stock: 3, lowStockThreshold: 8, category: 'Skin Care'),
    const ProductModel(id: 'p-27', name: 'Moisturiser 50ml', sku: 'MS-001', price: 650, cost: 380, stock: 10, lowStockThreshold: 5, category: 'Skin Care'),
    const ProductModel(id: 'p-28', name: 'Sunscreen SPF50 60ml', sku: 'SS-001', price: 520, cost: 300, stock: 8, lowStockThreshold: 5, category: 'Skin Care'),
    // ── Nails ─────────────────────────────────────────────────────────────
    const ProductModel(id: 'p-29', name: 'OPI Nail Polish', sku: 'ON-001', price: 900, cost: 550, stock: 3, lowStockThreshold: 5, category: 'Nails'),
    const ProductModel(id: 'p-30', name: 'Nail Remover 100ml', sku: 'NR-001', price: 150, cost: 80, stock: 6, lowStockThreshold: 10, category: 'Nails'),
    const ProductModel(id: 'p-31', name: 'Nail File (Pack 10)', sku: 'NF-001', price: 100, cost: 50, stock: 20, lowStockThreshold: 8, category: 'Nails'),
    // ── Massage ───────────────────────────────────────────────────────────
    const ProductModel(id: 'p-32', name: 'Massage Oil 200ml', sku: 'MO-001', price: 850, cost: 500, stock: 18, lowStockThreshold: 5, category: 'Massage'),
    const ProductModel(id: 'p-33', name: 'Almond Oil 100ml', sku: 'AO-001', price: 320, cost: 180, stock: 14, lowStockThreshold: 5, category: 'Massage'),
  ];

  final List<InventoryLogEntry> _logs = [];

  Future<List<ProductModel>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _products;
  }

  Future<List<ProductModel>> getByCategory(String category) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _products.where((p) => p.category == category).toList();
  }

  Future<List<ProductModel>> getLowStock() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _products.where((p) => p.isLowStock).toList();
  }

  Future<List<String>> getCategories() async {
    final cats = _products.map((p) => p.category ?? 'Other').toSet().toList();
    cats.sort();
    return cats;
  }

  Future<List<InventoryLogEntry>> getLogs() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _logs;
  }
}
