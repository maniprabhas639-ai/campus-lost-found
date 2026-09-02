import 'models/lost_found_item.dart';

const List<LostFoundItem> mockLostFoundItems = [
  LostFoundItem(
    id: 'item-001',
    title: 'Black Backpack',
    description: 'Black backpack with a laptop compartment.',
    category: 'Bags',
    type: LostFoundType.lost,
    location: 'Central Library',
    date: 'Today',
  ),
  LostFoundItem(
    id: 'item-002',
    title: 'Student ID Card',
    description: 'Student ID card found near the main entrance.',
    category: 'Documents',
    type: LostFoundType.found,
    location: 'Main Entrance',
    date: 'Yesterday',
  ),
  LostFoundItem(
    id: 'item-003',
    title: 'Wireless Earbuds',
    description: 'White wireless earbuds in a small charging case.',
    category: 'Electronics',
    type: LostFoundType.lost,
    location: 'Computer Lab',
    date: '2 days ago',
  ),
  LostFoundItem(
    id: 'item-004',
    title: 'Blue Water Bottle',
    description: 'Blue reusable water bottle.',
    category: 'Accessories',
    type: LostFoundType.found,
    location: 'Sports Complex',
    date: '3 days ago',
  ),
];