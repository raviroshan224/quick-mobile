import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../data/image_library_repository.dart';
import '../../models/image_asset_model.dart';

final imageLibraryRepoProvider = Provider<ImageLibraryRepository>(
  (ref) => ImageLibraryRepository(
    ref.read(apiClientProvider),
    ref.read(dioProvider),
  ),
);

final imageAssetsProvider =
    FutureProvider.autoDispose.family<List<ImageAsset>, String?>((ref, type) async {
  return ref.read(imageLibraryRepoProvider).getAll(type: type);
});

class ImageLibraryNotifier extends StateNotifier<AsyncValue<List<ImageAsset>>> {
  ImageLibraryNotifier(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  final ImageLibraryRepository _repo;
  String? _activeType;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getAll(type: _activeType));
  }

  Future<void> filter(String? type) async {
    _activeType = type;
    await _load();
  }

  Future<void> upload({
    required XFile file,
    required String type,
    String? name,
  }) async {
    await _repo.upload(file: file, type: type, name: name);
    await _load();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncValue.data(
      state.value?.where((img) => img.id != id).toList() ?? [],
    );
  }

  Future<void> refresh() => _load();
}

final imageLibraryNotifierProvider =
    StateNotifierProvider.autoDispose<ImageLibraryNotifier, AsyncValue<List<ImageAsset>>>(
  (ref) => ImageLibraryNotifier(ref.read(imageLibraryRepoProvider)),
);
