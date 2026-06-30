import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/image_library/models/image_asset_model.dart';
import '../../../../features/image_library/presentation/providers/image_library_provider.dart';

// type filter → API string
const _kTypes = <String, String?>{
  'All': null,
  'Services': 'SERVICE_ICON',
  'Staff': 'STAFF_PHOTO',
  'Products': 'PRODUCT_IMAGE',
};

class ImageLibraryScreen extends ConsumerStatefulWidget {
  const ImageLibraryScreen({super.key});

  @override
  ConsumerState<ImageLibraryScreen> createState() => _ImageLibraryScreenState();
}

class _ImageLibraryScreenState extends ConsumerState<ImageLibraryScreen> {
  String _filterLabel = 'All';
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ImageAsset> _filtered(List<ImageAsset> all) {
    var list = all;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((img) => img.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;

    final type = await _showTypePicker();
    if (type == null || !mounted) return;

    final nameCtrl = TextEditingController(
      text: picked.name.replaceAll(RegExp(r'\.\w+$'), ''),
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Name this image',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Haircut Icon'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Upload')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(imageLibraryNotifierProvider.notifier).upload(
            file: File(picked.path),
            type: type,
            name: nameCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Image uploaded'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ));
      }
    }
  }

  Future<String?> _showTypePicker() => showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Image type',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              for (final entry in const {
                'Service Icon': 'SERVICE_ICON',
                'Staff Photo': 'STAFF_PHOTO',
                'Product Image': 'PRODUCT_IMAGE',
              }.entries)
                ListTile(
                  title: Text(entry.key),
                  onTap: () => Navigator.pop(ctx, entry.value),
                ),
            ],
          ),
        ),
      );

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Upload Image',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text('Choose an image source.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          _UploadOption(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            onTap: () {
              Navigator.of(ctx).pop();
              _pickAndUpload(ImageSource.camera);
            },
          ),
          const SizedBox(height: 8),
          _UploadOption(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            onTap: () {
              Navigator.of(ctx).pop();
              _pickAndUpload(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: const Text('Cancel',
                  style: TextStyle(fontSize: 15, color: AppColors.textTertiary)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagesAsync = ref.watch(imageLibraryNotifierProvider);
    final isLoading = ref.watch(
      imageLibraryNotifierProvider.select((s) => s.isLoading),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.go(AppRoutes.more),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Colors.black),
                ),
                const Spacer(),
                const Text('Image Library',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  GestureDetector(
                    onTap: () => ref.read(imageLibraryNotifierProvider.notifier).refresh(),
                    child: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.textSecondary),
                  ),
              ]),
            ),
            const SizedBox(height: 16),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search images…',
                  hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textTertiary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            setState(() => _searchQuery = '');
                            _searchCtrl.clear();
                          },
                          child: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black, width: 1.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Category chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: _kTypes.keys.map((label) {
                  final selected = _filterLabel == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _filterLabel = label);
                        ref
                            .read(imageLibraryNotifierProvider.notifier)
                            .filter(_kTypes[label]);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: selected ? Colors.black : AppColors.divider,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: imagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 40, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      Text('$e',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () =>
                            ref.read(imageLibraryNotifierProvider.notifier).refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (all) {
                  final filtered = _filtered(all);
                  if (filtered.isEmpty) {
                    return _EmptyState(query: _searchQuery);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          '${filtered.length} image${filtered.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _GridItem(
                            asset: filtered[i],
                            onDelete: () => ref
                                .read(imageLibraryNotifierProvider.notifier)
                                .delete(filtered[i].id),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: GestureDetector(
          onTap: _showUploadDialog,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(26),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Upload Image',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Grid item ────────────────────────────────────────────────────────────────

class _GridItem extends StatelessWidget {
  const _GridItem({required this.asset, required this.onDelete});
  final ImageAsset asset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(13)),
                child: Image.network(
                  asset.url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _e, _st) => Container(
                    color: AppColors.surfaceVariant,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.textTertiary, size: 28),
                  ),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Text(
                asset.name,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(asset.url,
                  width: 80, height: 80, fit: BoxFit.cover,
                  errorBuilder: (_, _e, _st) => Container(
                      width: 80,
                      height: 80,
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.textTertiary))),
            ),
            const SizedBox(height: 12),
            Text(asset.name,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(26)),
                alignment: Alignment.center,
                child: const Text('Delete',
                    style: TextStyle(
                        color: AppColors.danger,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.query});
  final String? query;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query != null && query!.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.photo_library_outlined,
                  size: 30, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No results for "$query"' : 'No images yet',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Try a different keyword or clear the filter.'
                  : 'Upload your first image using the button below.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textTertiary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Upload option row ────────────────────────────────────────────────────────

class _UploadOption extends StatelessWidget {
  const _UploadOption(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}
