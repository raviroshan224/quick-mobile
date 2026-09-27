/// The kind of business an account runs. Drives wording (what the business
/// is called, example text) and which features the app shows — a pharmacy
/// has no bookings, services or tips, for example.
enum BusinessType {
  salon,
  pharmacy,
  retail;

  static BusinessType? tryParse(String? s) => switch (s?.toUpperCase()) {
        'SALON' => BusinessType.salon,
        'PHARMACY' => BusinessType.pharmacy,
        'RETAIL' => BusinessType.retail,
        _ => null,
      };

  String toApi() => name.toUpperCase();

  String get label => switch (this) {
        BusinessType.salon => 'Salon',
        BusinessType.pharmacy => 'Pharmacy',
        BusinessType.retail => 'Retail shop',
      };

  String get description => switch (this) {
        BusinessType.salon => 'Services, bookings and staff commissions',
        BusinessType.pharmacy => 'Medicines and products, sold over the counter',
        BusinessType.retail => 'Products sold over the counter',
      };

  // ── Wording ────────────────────────────────────────────────────────────────

  /// Lower-case noun for the business, used mid-sentence ("your pharmacy").
  String get noun => switch (this) {
        BusinessType.salon => 'salon',
        BusinessType.pharmacy => 'pharmacy',
        BusinessType.retail => 'shop',
      };

  /// Example business name for the name field.
  String get nameHint => switch (this) {
        BusinessType.salon => "Jane's Salon",
        BusinessType.pharmacy => 'City Pharmacy',
        BusinessType.retail => 'Corner Store',
      };

  /// Example product category for the item form.
  String get itemCategoryHint => switch (this) {
        BusinessType.salon => 'e.g. Hair Care (optional)',
        BusinessType.pharmacy => 'e.g. Pain Relief (optional)',
        BusinessType.retail => 'e.g. Snacks (optional)',
      };

  /// Example discount name for the discount form.
  String get discountNameHint => switch (this) {
        BusinessType.salon => 'e.g. Hair 10% Off, Facial Special',
        BusinessType.pharmacy => 'e.g. Senior Citizen 10%, Vitamins Offer',
        BusinessType.retail => 'e.g. Festive 10% Off',
      };

  // ── Features ───────────────────────────────────────────────────────────────

  /// Services (treatments sold by time, with a staff member) and the
  /// Checkout "Services" tab.
  bool get hasServices => this == BusinessType.salon;

  /// Appointment bookings and the Checkout "Calendar" tab.
  bool get hasBookings => this == BusinessType.salon;

  /// Tips on a sale.
  bool get hasTips => this == BusinessType.salon;

  /// Staff specialties (e.g. "Haircut") on the staff form.
  bool get hasStaffSpecialties => this == BusinessType.salon;

  /// Medicine details on products (generic name, strength, prescription…).
  bool get hasMedicineFields => this == BusinessType.pharmacy;

  /// Batch numbers and expiry dates on stock, the expiring-stock screen and
  /// the dashboard expiry alert. Off for salons, whose products rarely
  /// need it; pharmacies and shops (food, cosmetics) do.
  bool get hasExpiryTracking => this != BusinessType.salon;
}
