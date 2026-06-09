import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/image_asset_model.dart';

final imageLibraryProvider = FutureProvider.family<List<ImageAsset>, ImageAssetType?>((ref, type) async {
  final client = ref.watch(apiClientProvider);
  final typeParam = switch (type) {
    ImageAssetType.serviceIcon => 'SERVICE_ICON',
    ImageAssetType.staffPhoto => 'STAFF_PHOTO',
    ImageAssetType.productImage => 'PRODUCT_IMAGE',
    ImageAssetType.customerPhoto => 'CUSTOMER_PHOTO',
    null => null,
  };
  final response = await client.get<Map<String, dynamic>>(
    '/images',
    queryParameters: typeParam != null ? {'type': typeParam} : null,
  );
  final list = response['data'] as List;
  return list.map((e) => ImageAsset.fromJson(e as Map<String, dynamic>)).toList();
});
