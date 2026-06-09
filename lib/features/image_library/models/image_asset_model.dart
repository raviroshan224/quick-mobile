enum ImageAssetType { serviceIcon, staffPhoto, productImage, customerPhoto }

class ImageAsset {
  final String id;
  final String name;
  final String url;
  final ImageAssetType type;
  final bool isDefault;

  const ImageAsset({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.isDefault,
  });

  factory ImageAsset.fromJson(Map<String, dynamic> j) => ImageAsset(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
        type: _typeFromString(j['type'] as String),
        isDefault: j['isDefault'] as bool? ?? false,
      );

  static ImageAssetType _typeFromString(String s) => switch (s) {
        'SERVICE_ICON' => ImageAssetType.serviceIcon,
        'STAFF_PHOTO' => ImageAssetType.staffPhoto,
        'PRODUCT_IMAGE' => ImageAssetType.productImage,
        _ => ImageAssetType.customerPhoto,
      };
}
