import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/image_asset_model.dart';

class ImageLibraryRepository {
  ImageLibraryRepository(this._api, this._dio);
  final ApiClient _api;
  final Dio _dio;

  Future<List<ImageAsset>> getAll({String? type}) async {
    final data = await _api.get('/images', queryParameters: {
      'type': ?type,
    });
    return (data as List)
        .map((e) => ImageAsset.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ImageAsset> upload({
    required File file,
    required String type,
    String? name,
    bool isDefault = false,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split(Platform.pathSeparator).last,
      ),
      'type': type,
      if (name != null && name.isNotEmpty) 'name': name,
      'isDefault': isDefault.toString(),
    });
    final response = await _dio.post('/images/upload', data: formData);
    final body = response.data;
    final json = (body is Map<String, dynamic> && body.containsKey('data'))
        ? body['data'] as Map<String, dynamic>
        : body as Map<String, dynamic>;
    return ImageAsset.fromJson(json);
  }

  Future<void> delete(String id) async {
    await _api.delete('/images/$id');
  }
}
