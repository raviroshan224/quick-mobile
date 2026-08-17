class PaymentMode {
  final String id;
  final String name;
  final String qrImageUrl;
  final bool isActive;

  const PaymentMode({
    required this.id,
    required this.name,
    required this.qrImageUrl,
    this.isActive = true,
  });

  PaymentMode copyWith({String? name, String? qrImageUrl, bool? isActive}) => PaymentMode(
        id: id,
        name: name ?? this.name,
        qrImageUrl: qrImageUrl ?? this.qrImageUrl,
        isActive: isActive ?? this.isActive,
      );

  factory PaymentMode.fromJson(Map<String, dynamic> j) => PaymentMode(
        id: j['id'] as String,
        name: j['name'] as String,
        qrImageUrl: j['qrImageUrl'] as String,
        isActive: j['isActive'] as bool? ?? true,
      );
}
