import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Reads a provider's `gallery` field (list of image URLs) defensively.
List<String> providerGalleryUrls(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => '$e').where((e) => e.startsWith('http')).toList();
}

Widget _imageFallback({double? size}) => Container(
      width: size,
      height: size,
      color: AppTheme.slate100,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: AppTheme.slate400, size: 22),
    );

Widget _loading(BuildContext context, Widget child, ImageChunkEvent? progress, {double? size}) {
  if (progress == null) return child;
  return Container(
    width: size,
    height: size,
    color: AppTheme.slate100,
    alignment: Alignment.center,
    child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)),
  );
}

/// Wide cover banner at the top of a provider profile.
class ProviderCover extends StatelessWidget {
  final String url;
  final double height;

  const ProviderCover({super.key, required this.url, this.height = 150});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppTheme.radiusCard,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.4),
          cacheWidth: 1000,
          loadingBuilder: (c, child, p) => _loading(c, child, p),
          errorBuilder: (_, _, _) => _imageFallback(),
        ),
      ),
    );
  }
}

/// "Çalışmalarım" strip: thumbnails of the provider's own work photos; a tap
/// opens the full-screen viewer.
class ProviderGallerySection extends StatelessWidget {
  final List<String> urls;
  final String title;

  const ProviderGallerySection({super.key, required this.urls, this.title = 'Çalışmalarım'});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text('${urls.length} fotoğraf', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 12, color: AppTheme.slate400)),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: ListView.separated(
            key: const Key('provider_gallery_list'),
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => GestureDetector(
              key: Key('gallery_thumb_$index'),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ProviderGalleryViewer(urls: urls, initialIndex: index)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  urls[index],
                  width: 116,
                  height: 116,
                  fit: BoxFit.cover,
                  cacheWidth: 360,
                  loadingBuilder: (c, child, p) => _loading(c, child, p, size: 116),
                  errorBuilder: (_, _, _) => _imageFallback(size: 116),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen, swipeable, pinch-to-zoom viewer for work photos.
class ProviderGalleryViewer extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const ProviderGalleryViewer({super.key, required this.urls, this.initialIndex = 0});

  @override
  State<ProviderGalleryViewer> createState() => _ProviderGalleryViewerState();
}

class _ProviderGalleryViewerState extends State<ProviderGalleryViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('${_index + 1} / ${widget.urls.length}', style: const TextStyle(fontFamily: AppTheme.fontFamily, fontSize: 15)),
      ),
      body: PageView.builder(
        key: const Key('gallery_viewer_pages'),
        controller: _controller,
        itemCount: widget.urls.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.urls[i],
              fit: BoxFit.contain,
              loadingBuilder: (c, child, p) => p == null
                  ? child
                  : const Center(child: CircularProgressIndicator(color: Colors.white)),
              errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined, color: Colors.white54, size: 48),
            ),
          ),
        ),
      ),
    );
  }
}
