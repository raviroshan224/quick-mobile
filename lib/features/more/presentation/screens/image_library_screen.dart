import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';

// ─── Data model ───────────────────────────────────────────────────────────────

enum _ImageCategory { service, staff, product }

class _MockImage {
  const _MockImage({
    required this.id,
    required this.name,
    required this.category,
    required this.iconData,
    required this.color,
    this.initials,
  });
  final String id;
  final String name;
  final _ImageCategory category;
  final IconData iconData;
  final Color color;
  final String? initials; // for staff avatars
}

// ─── Mock data ────────────────────────────────────────────────────────────────

const _kServiceColor = Color(0xFF3B82F6);
const _kStaffColor = Color(0xFF8B5CF6);
const _kProductColor = Color(0xFFF59E0B);

const _mockImages = <_MockImage>[
  // Services
  _MockImage(id: 's1', name: 'Haircut', category: _ImageCategory.service, iconData: Icons.content_cut, color: _kServiceColor),
  _MockImage(id: 's2', name: 'Facial', category: _ImageCategory.service, iconData: Icons.spa, color: _kServiceColor),
  _MockImage(id: 's3', name: 'Manicure', category: _ImageCategory.service, iconData: Icons.touch_app, color: _kServiceColor),
  _MockImage(id: 's4', name: 'Massage', category: _ImageCategory.service, iconData: Icons.self_improvement, color: _kServiceColor),
  _MockImage(id: 's5', name: 'Hair Color', category: _ImageCategory.service, iconData: Icons.palette, color: _kServiceColor),
  _MockImage(id: 's6', name: 'Pedicure', category: _ImageCategory.service, iconData: Icons.directions_walk, color: _kServiceColor),
  _MockImage(id: 's7', name: 'Makeup', category: _ImageCategory.service, iconData: Icons.auto_fix_high, color: _kServiceColor),
  _MockImage(id: 's8', name: 'Waxing', category: _ImageCategory.service, iconData: Icons.bolt, color: _kServiceColor),
  // Staff
  _MockImage(id: 'st1', name: 'Priya Sharma', category: _ImageCategory.staff, iconData: Icons.person, color: _kStaffColor, initials: 'PS'),
  _MockImage(id: 'st2', name: 'Anita Rai', category: _ImageCategory.staff, iconData: Icons.person, color: _kStaffColor, initials: 'AR'),
  _MockImage(id: 'st3', name: 'Sita Thapa', category: _ImageCategory.staff, iconData: Icons.person, color: _kStaffColor, initials: 'ST'),
  _MockImage(id: 'st4', name: 'Maya Gurung', category: _ImageCategory.staff, iconData: Icons.person, color: _kStaffColor, initials: 'MG'),
  // Products
  _MockImage(id: 'p1', name: 'Shampoo', category: _ImageCategory.product, iconData: Icons.water_drop, color: _kProductColor),
  _MockImage(id: 'p2', name: 'Scissors', category: _ImageCategory.product, iconData: Icons.content_cut, color: _kProductColor),
  _MockImage(id: 'p3', name: 'Comb', category: _ImageCategory.product, iconData: Icons.brush, color: _kProductColor),
  _MockImage(id: 'p4', name: 'Face Wash', category: _ImageCategory.product, iconData: Icons.face_retouching_natural, color: _kProductColor),
  _MockImage(id: 'p5', name: 'Hair Color', category: _ImageCategory.product, iconData: Icons.palette, color: _kProductColor),
  _MockImage(id: 'p6', name: 'Blade', category: _ImageCategory.product, iconData: Icons.hardware, color: _kProductColor),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class ImageLibraryScreen extends StatefulWidget {
  const ImageLibraryScreen({super.key});

  @override
  State<ImageLibraryScreen> createState() => _ImageLibraryScreenState();
}

class _ImageLibraryScreenState extends State<ImageLibraryScreen> {
  _ImageCategory? _selectedCategory; // null = All
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_MockImage> get _filtered {
    var list = _mockImages.toList();
    if (_selectedCategory != null) {
      list = list.where((img) => img.category == _selectedCategory).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((img) => img.name.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  void _showItemSheet(_MockImage image) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ImageActionSheet(image: image),
    );
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Upload Image',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: const Text('Choose an image source.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          _UploadOption(
            icon: Icons.camera_alt_rounded,
            label: 'Camera',
            onTap: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Camera — coming soon'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.black,
                duration: Duration(seconds: 2),
              ));
            },
          ),
          const SizedBox(height: 8),
          _UploadOption(
            icon: Icons.photo_library_rounded,
            label: 'Gallery',
            onTap: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Gallery — coming soon'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.black,
                duration: Duration(seconds: 2),
              ));
            },
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => Navigator.of(ctx).pop(),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: const Text('Cancel',
                  style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF))),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
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
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                const SizedBox(width: 18),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Search bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search images…',
                  hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: Color(0xFF9CA3AF)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            setState(() => _searchQuery = '');
                            _searchCtrl.clear();
                          },
                          child: const Icon(Icons.close,
                              size: 16, color: Color(0xFF9CA3AF)),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
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

            // ── Category tabs ─────────────────────────────────────────────────
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _CategoryChip(
                  label: 'All',
                  selected: _selectedCategory == null,
                  onTap: () => setState(() => _selectedCategory = null),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Services',
                  selected: _selectedCategory == _ImageCategory.service,
                  color: _kServiceColor,
                  onTap: () => setState(
                      () => _selectedCategory = _ImageCategory.service),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Staff',
                  selected: _selectedCategory == _ImageCategory.staff,
                  color: _kStaffColor,
                  onTap: () => setState(
                      () => _selectedCategory = _ImageCategory.staff),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Products',
                  selected: _selectedCategory == _ImageCategory.product,
                  color: _kProductColor,
                  onTap: () => setState(
                      () => _selectedCategory = _ImageCategory.product),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // ── Count label ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${filtered.length} image${filtered.length == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 10),

            // ── Grid / empty state ────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(
                      query: _searchQuery,
                      category: _selectedCategory,
                    )
                  : GridView.count(
                      crossAxisCount: 3,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: filtered
                          .map((img) => _GridItem(
                                image: img,
                                onTap: () => _showItemSheet(img),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),

      // ── Upload button ─────────────────────────────────────────────────────
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
  const _GridItem({required this.image, required this.onTap});
  final _MockImage image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isStaff = image.category == _ImageCategory.staff;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                decoration: BoxDecoration(
                  color: image.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: isStaff && image.initials != null
                      ? Text(
                          image.initials!,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: image.color,
                          ),
                        )
                      : Icon(image.iconData, size: 30, color: image.color),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Text(
                image.name,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
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
}

// ─── Category chip ────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: color == null ? 1.0 : 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? activeColor : const Color(0xFFE5E7EB),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? (color == null ? Colors.white : activeColor)
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ─── Image action bottom sheet ────────────────────────────────────────────────

class _ImageActionSheet extends StatelessWidget {
  const _ImageActionSheet({required this.image});
  final _MockImage image;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Preview
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: image.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: image.category == _ImageCategory.staff &&
                      image.initials != null
                  ? Text(
                      image.initials!,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: image.color),
                    )
                  : Icon(image.iconData, size: 36, color: image.color),
            ),
          ),
          const SizedBox(height: 12),
          Text(image.name,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          Text(
            _categoryLabel(image.category),
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 24),
          // Select button
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('"${image.name}" selected'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.black,
                duration: const Duration(seconds: 2),
              ));
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: const Text('Select',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 10),
          // Delete button
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('"${image.name}" deleted'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFFEF4444),
                duration: const Duration(seconds: 2),
              ));
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: const Text('Delete',
                  style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(_ImageCategory cat) {
    switch (cat) {
      case _ImageCategory.service:
        return 'Service';
      case _ImageCategory.staff:
        return 'Staff';
      case _ImageCategory.product:
        return 'Product';
    }
  }
}

// ─── Upload option row ────────────────────────────────────────────────────────

class _UploadOption extends StatelessWidget {
  const _UploadOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });
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
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: Colors.black87),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.query, this.category});
  final String? query;
  final _ImageCategory? category;

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
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.photo_library_outlined,
                  size: 30, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No results for "$query"' : 'No images',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF374151)),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Try a different keyword or change the category filter.'
                  : 'Upload your first image using the button below.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF9CA3AF), height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
