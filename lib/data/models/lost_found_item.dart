import 'package:cloud_firestore/cloud_firestore.dart';

enum LostFoundType {
  lost,
  found,
}

enum LostFoundStatus {
  active,
  resolved,
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
    this.status = LostFoundStatus.active,
    this.imageUrl,
    this.ownerId,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final LostFoundType type;
  final String location;
  final String date;
  final LostFoundStatus status;
  final String? imageUrl;
  final String? ownerId;

  String get typeLabel {
    switch (type) {
      case LostFoundType.lost:
        return 'Lost';
      case LostFoundType.found:
        return 'Found';
    }
  }

  String get statusLabel {
    switch (status) {
      case LostFoundStatus.active:
        return 'Active';
      case LostFoundStatus.resolved:
        return 'Resolved';
    }
  }

  factory LostFoundItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final Map<String, dynamic> data = document.data() ?? <String, dynamic>{};

    return LostFoundItem(
      id: document.id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      type: _typeFromString(data['type'] as String?),
      location: data['location'] as String? ?? '',
      date: data['date'] as String? ?? '',
      status: _statusFromString(data['status'] as String?),
      imageUrl: data['imageUrl'] as String?,
      ownerId: data['ownerId'] as String?,
    );
  }

  static LostFoundType _typeFromString(String? value) {
    switch (value) {
      case 'found':
        return LostFoundType.found;
      case 'lost':
      default:
        return LostFoundType.lost;
    }
  }

  static LostFoundStatus _statusFromString(String? value) {
    switch (value) {
      case 'resolved':
        return LostFoundStatus.resolved;
      case 'active':
      default:
        return LostFoundStatus.active;
    }
  }
}