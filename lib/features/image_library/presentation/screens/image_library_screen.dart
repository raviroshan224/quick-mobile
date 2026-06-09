import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';

class ImageLibraryScreen extends HookWidget {
  const ImageLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = useState('all');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Image Library',
                    style: AppTextStyles.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final f in ['all', 'service', 'staff', 'product'])
                        Padding(
                          padding: const EdgeInsets.only(
                              right: AppSpacing.sm,
                              bottom: AppSpacing.sm),
                          child: FilterChip(
                            label: Text(f[0].toUpperCase() + f.substring(1)),
                            selected: filter.value == f,
                            onSelected: (_) => filter.value = f,
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.12),
                            checkmarkColor: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No images yet',
              subtitle: 'Upload images for services, staff and products',
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.upload_rounded),
        label: const Text('Upload Image'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
