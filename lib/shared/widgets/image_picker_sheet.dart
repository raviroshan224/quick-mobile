import 'package:flutter/material.dart';

// ─── Value returned when user picks an image ─────────────────────────────────

class PickedImage {
  const PickedImage({
    required this.id,
    required this.name,
    required this.iconData,
    required this.color,
    this.initials,
  });
  final String id;
  final String name;
  final IconData iconData;
  final Color color;
  final String? initials;
}

// ─── Category filter ──────────────────────────────────────────────────────────

enum ImagePickerCategory { all, service, staff, product }

// ─── Internal image data ──────────────────────────────────────────────────────

class _LibImage {
  const _LibImage({
    required this.id,
    required this.name,
    required this.category,
    required this.iconData,
    required this.color,
    this.initials,
  });
  final String id;
  final String name;
  final ImagePickerCategory category;
  final IconData iconData;
  final Color color;
  final String? initials;

  PickedImage toPickedImage() => PickedImage(
        id: id,
        name: name,
        iconData: iconData,
        color: color,
        initials: initials,
      );
}

const _kServiceColor = Color(0xFF3B82F6);
const _kStaffColor = Color(0xFF8B5CF6);
const _kProductColor = Color(0xFFF59E0B);
const _kNeutralColor = Color(0xFF6B7280);

const _kLibrary = <_LibImage>[
  // ── Services ──────────────────────────────────────────────────────────────
  _LibImage(id: 'svc-cut',   name: 'Haircut',     category: ImagePickerCategory.service, iconData: Icons.content_cut,              color: _kServiceColor),
  _LibImage(id: 'svc-color', name: 'Hair Color',  category: ImagePickerCategory.service, iconData: Icons.palette,                  color: _kServiceColor),
  _LibImage(id: 'svc-blowdry', name: 'Blow Dry',  category: ImagePickerCategory.service, iconData: Icons.air,                      color: _kServiceColor),
  _LibImage(id: 'svc-facial', name: 'Facial',     category: ImagePickerCategory.service, iconData: Icons.spa,                      color: _kServiceColor),
  _LibImage(id: 'svc-mani',  name: 'Manicure',    category: ImagePickerCategory.service, iconData: Icons.touch_app,                color: _kServiceColor),
  _LibImage(id: 'svc-pedi',  name: 'Pedicure',    category: ImagePickerCategory.service, iconData: Icons.directions_walk,          color: _kServiceColor),
  _LibImage(id: 'svc-makeup', name: 'Makeup',     category: ImagePickerCategory.service, iconData: Icons.auto_fix_high,            color: _kServiceColor),
  _LibImage(id: 'svc-wax',   name: 'Waxing',      category: ImagePickerCategory.service, iconData: Icons.bolt,                     color: _kServiceColor),
  _LibImage(id: 'svc-massage', name: 'Massage',   category: ImagePickerCategory.service, iconData: Icons.self_improvement,         color: _kServiceColor),
  _LibImage(id: 'svc-thread', name: 'Threading',  category: ImagePickerCategory.service, iconData: Icons.loop,                     color: _kServiceColor),
  _LibImage(id: 'svc-keratin', name: 'Keratin',   category: ImagePickerCategory.service, iconData: Icons.waves,                    color: _kServiceColor),
  _LibImage(id: 'svc-nailart', name: 'Nail Art',  category: ImagePickerCategory.service, iconData: Icons.brush,                    color: _kServiceColor),
  // ── Staff ─────────────────────────────────────────────────────────────────
  _LibImage(id: 'stf-f1',  name: 'Female Stylist', category: ImagePickerCategory.staff, iconData: Icons.person,  color: _kStaffColor, initials: 'FS'),
  _LibImage(id: 'stf-m1',  name: 'Male Stylist',   category: ImagePickerCategory.staff, iconData: Icons.person,  color: Color(0xFF0EA5E9), initials: 'MS'),
  _LibImage(id: 'stf-mgr', name: 'Manager',        category: ImagePickerCategory.staff, iconData: Icons.manage_accounts, color: Color(0xFF10B981), initials: 'MG'),
  _LibImage(id: 'stf-rec', name: 'Receptionist',   category: ImagePickerCategory.staff, iconData: Icons.support_agent,   color: Color(0xFFF59E0B), initials: 'RC'),
  // ── Products ──────────────────────────────────────────────────────────────
  _LibImage(id: 'prd-shampoo', name: 'Shampoo',      category: ImagePickerCategory.product, iconData: Icons.water_drop,           color: _kProductColor),
  _LibImage(id: 'prd-cond',    name: 'Conditioner',  category: ImagePickerCategory.product, iconData: Icons.opacity,              color: _kProductColor),
  _LibImage(id: 'prd-scissors', name: 'Scissors',    category: ImagePickerCategory.product, iconData: Icons.content_cut,          color: _kProductColor),
  _LibImage(id: 'prd-comb',    name: 'Comb',         category: ImagePickerCategory.product, iconData: Icons.brush,                color: _kProductColor),
  _LibImage(id: 'prd-facewash', name: 'Face Wash',   category: ImagePickerCategory.product, iconData: Icons.face_retouching_natural, color: _kProductColor),
  _LibImage(id: 'prd-cream',   name: 'Cream',        category: ImagePickerCategory.product, iconData: Icons.science,              color: _kProductColor),
  _LibImage(id: 'prd-color',   name: 'Hair Color',   category: ImagePickerCategory.product, iconData: Icons.palette,              color: _kProductColor),
  _LibImage(id: 'prd-blade',   name: 'Blade',        category: ImagePickerCategory.product, iconData: Icons.hardware,             color: _kProductColor),
  _LibImage(id: 'prd-gloves',  name: 'Gloves',       category: ImagePickerCategory.product, iconData: Icons.back_hand_outlined,   color: _kProductColor),
  _LibImage(id: 'prd-towel',   name: 'Towel',        category: ImagePickerCategory.product, iconData: Icons.dry_cleaning,         color: _kProductColor),
  // ── Neutral / general ──────────────────────────────────────────────────────
  _LibImage(id: 'gen-star',  name: 'Star',        category: ImagePickerCategory.all, iconData: Icons.star_rounded,       color: _kNeutralColor),
  _LibImage(id: 'gen-heart', name: 'Heart',       category: ImagePickerCategory.all, iconData: Icons.favorite_rounded,   color: Color(0xFFEF4444)),
  _LibImage(id: 'gen-crown', name: 'Crown',       category: ImagePickerCategory.all, iconData: Icons.workspace_premium,  color: Color(0xFFD97706)),
  _LibImage(id: 'gen-leaf',  name: 'Leaf',        category: ImagePickerCategory.all, iconData: Icons.eco_rounded,        color: Color(0xFF16A34A)),
];

// ─── Sheet ────────────────────────────────────────────────────────────────────

class ImagePickerSheet extends StatefulWidget {
  const ImagePickerSheet({
    super.key,
    this.initialCategory = ImagePickerCategory.all,
    this.title = 'Pick an Image',
  });

  final ImagePickerCategory initialCategory;
  final String title;

  // Convenience: show as modal and return selection
  static Future<PickedImage?> show(
    BuildContext context, {
    ImagePickerCategory initialCategory = ImagePickerCategory.all,
    String title = 'Pick an Image',
  }) {
    return showModalBottomSheet<PickedImage>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ImagePickerSheet(
        initialCategory: initialCategory,
        title: title,
      ),
    );
  }

  @override
  State<ImagePickerSheet> createState() => _ImagePickerSheetState();
}

class _ImagePickerSheetState extends State<ImagePickerSheet> {
  late ImagePickerCategory _cat;
  String _query = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cat = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_LibImage> get _filtered {
    var list = _kLibrary.where((img) {
      if (_cat != ImagePickerCategory.all && img.category != _cat) {
        return false;
      }
      if (_query.isNotEmpty &&
          !img.name.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── Handle ────────────────────────────────────────────────────
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // ── Title ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                const Spacer(),
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded,
                      size: 20, color: Color(0xFF6B7280)),
                ),
              ]),
            ),
            const SizedBox(height: 14),

            // ── Search ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search images…',
                  hintStyle: const TextStyle(
                      fontSize: 14, color: Color(0xFF9CA3AF)),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: Color(0xFF9CA3AF)),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            setState(() => _query = '');
                            _searchCtrl.clear();
                          },
                          child: const Icon(Icons.close,
                              size: 16, color: Color(0xFF9CA3AF)),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF3F4F6),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // ── Category tabs ─────────────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _Tab(
                    label: 'All',
                    selected: _cat == ImagePickerCategory.all,
                    onTap: () =>
                        setState(() => _cat = ImagePickerCategory.all),
                  ),
                  _Tab(
                    label: 'Services',
                    selected: _cat == ImagePickerCategory.service,
                    onTap: () =>
                        setState(() => _cat = ImagePickerCategory.service),
                  ),
                  _Tab(
                    label: 'Staff',
                    selected: _cat == ImagePickerCategory.staff,
                    onTap: () =>
                        setState(() => _cat = ImagePickerCategory.staff),
                  ),
                  _Tab(
                    label: 'Products',
                    selected: _cat == ImagePickerCategory.product,
                    onTap: () =>
                        setState(() => _cat = ImagePickerCategory.product),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Grid ──────────────────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image_not_supported_outlined,
                              size: 40, color: Color(0xFFD1D5DB)),
                          const SizedBox(height: 10),
                          Text(
                            _query.isNotEmpty
                                ? 'No results for "$_query"'
                                : 'No images in this category',
                            style: const TextStyle(
                                fontSize: 14, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _ImageCell(
                        image: filtered[i],
                        onTap: () =>
                            Navigator.pop(context, filtered[i].toPickedImage()),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Internal widgets ─────────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  const _Tab(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(right: 8),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.black : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? Colors.white : const Color(0xFF374151),
            ),
          ),
        ),
      );
}

class _ImageCell extends StatelessWidget {
  const _ImageCell({required this.image, required this.onTap});
  final _LibImage image;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 64,
              decoration: BoxDecoration(
                color: image.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: image.color.withValues(alpha: 0.2)),
              ),
              child: image.initials != null
                  ? Center(
                      child: Text(
                        image.initials!,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: image.color,
                        ),
                      ),
                    )
                  : Icon(image.iconData, size: 28, color: image.color),
            ),
            const SizedBox(height: 5),
            Text(
              image.name,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF6B7280)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

// ─── Reusable avatar widget for forms ────────────────────────────────────────
// Shows picked image or falls back to initials / icon.
// Tap overlay triggers the picker.

class PickableAvatar extends StatelessWidget {
  const PickableAvatar({
    super.key,
    required this.radius,
    required this.fallbackInitials,
    required this.fallbackColor,
    this.picked,
    required this.onTap,
    this.fallbackIcon,
  });

  final double radius;
  final String fallbackInitials;
  final Color fallbackColor;
  final PickedImage? picked;
  final VoidCallback onTap;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final bg = picked != null
        ? picked!.color.withValues(alpha: 0.15)
        : fallbackColor;
    final size = radius * 2;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
            ),
            child: picked != null
                ? (picked!.initials != null
                    ? Center(
                        child: Text(
                          picked!.initials!,
                          style: TextStyle(
                            fontSize: radius * 0.55,
                            fontWeight: FontWeight.w700,
                            color: picked!.color,
                          ),
                        ),
                      )
                    : Icon(picked!.iconData,
                        size: radius * 0.8, color: picked!.color))
                : (fallbackIcon != null
                    ? Icon(fallbackIcon, size: radius * 0.8, color: fallbackColor)
                    : Center(
                        child: Text(
                          fallbackInitials,
                          style: TextStyle(
                            fontSize: radius * 0.55,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )),
          ),
          // Camera badge
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: radius * 0.72,
              height: radius * 0.72,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(
                Icons.photo_library_outlined,
                size: radius * 0.38,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
