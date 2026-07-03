class GalleryImageItem {
  const GalleryImageItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.publishedAt,
  });

  final int id;
  final String title;
  final String category;
  final String description;
  final String imageUrl;
  final String publishedAt;

  factory GalleryImageItem.fromJson(Map<String, dynamic> json) {
    return GalleryImageItem(
      id: int.tryParse('${json['id']}') ?? 0,
      title: '${json['title'] ?? ''}',
      category: '${json['category'] ?? 'General'}',
      description: '${json['description'] ?? ''}',
      imageUrl: '${json['image_url'] ?? ''}',
      publishedAt: '${json['published_at'] ?? ''}',
    );
  }
}
