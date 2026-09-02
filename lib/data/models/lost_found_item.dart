enum LostFoundType {
  lost,
  found,
}

class LostFoundItem {
  const LostFoundItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.location,
    required this.date,
    this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final LostFoundType type;
  final String location;
  final String date;
  final String? imageUrl;

  String get typeLabel {
    switch (type) {
      case LostFoundType.lost:
        return 'Lost';
      case LostFoundType.found:
        return 'Found';
    }
  }
}