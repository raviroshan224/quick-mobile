import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/image_library_provider.dart';
import '../models/image_asset_model.dart';

class ImageLibraryScreen extends ConsumerStatefulWidget {
  const ImageLibraryScreen({super.key});

  @override
  ConsumerState<ImageLibraryScreen> createState() => _ImageLibraryScreenState();
}

class _ImageLibraryScreenState extends ConsumerState<ImageLibraryScreen> {
  ImageAssetType? _selectedType;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(imageLibraryProvider(_selectedType));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Library'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _TypeChip(label: 'All', selected: _selectedType == null, onTap: () => setState(() => _selectedType = null)),
                _TypeChip(label: 'Service Icons', selected: _selectedType == ImageAssetType.serviceIcon, onTap: () => setState(() => _selectedType = ImageAssetType.serviceIcon)),
                _TypeChip(label: 'Staff Photos', selected: _selectedType == ImageAssetType.staffPhoto, onTap: () => setState(() => _selectedType = ImageAssetType.staffPhoto)),
                _TypeChip(label: 'Products', selected: _selectedType == ImageAssetType.productImage, onTap: () => setState(() => _selectedType = ImageAssetType.productImage)),
                _TypeChip(label: 'Customers', selected: _selectedType == ImageAssetType.customerPhoto, onTap: () => setState(() => _selectedType = ImageAssetType.customerPhoto)),
              ],
            ),
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (images) => GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
          itemCount: images.length,
          itemBuilder: (_, i) {
            final img = images[i];
            return Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(img.url, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image))),
                ),
                if (img.isDefault)
                  Positioned(top: 4, right: 4, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Default', style: TextStyle(color: Colors.white, fontSize: 10)),
                  )),
                Positioned(bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: Text(img.name, style: const TextStyle(color: Colors.white, fontSize: 11), overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}
