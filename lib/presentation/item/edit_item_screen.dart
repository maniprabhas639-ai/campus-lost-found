import 'package:flutter/material.dart';

import '../../core/constants/item_categories.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/lost_found_item.dart';
import '../../data/services/firestore_service.dart';

class EditItemScreen extends StatefulWidget {
  const EditItemScreen({super.key, required this.item});

  final LostFoundItem item;

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _dateController;

  late LostFoundType _selectedType;
  late String _selectedCategory;

  final FirestoreService _firestoreService = FirestoreService();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController = TextEditingController(
      text: widget.item.description,
    );
    _locationController = TextEditingController(text: widget.item.location);
    _dateController = TextEditingController(text: widget.item.date);

    _selectedType = widget.item.type;

    _selectedCategory = ItemCategories.values.contains(widget.item.category)
        ? widget.item.category
        : 'Other';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    if (_isSaving) {
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime initialDate =
        _parseDate(_dateController.text) ?? now;

    final DateTime safeInitialDate = initialDate.isAfter(now)
        ? now
        : initialDate;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: safeInitialDate,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _dateController.text =
          '${pickedDate.day.toString().padLeft(2, '0')}/'
          '${pickedDate.month.toString().padLeft(2, '0')}/'
          '${pickedDate.year}';
    });
  }

  DateTime? _parseDate(String value) {
    final DateTime? parsedDate = DateTime.tryParse(value);

    if (parsedDate != null) {
      return parsedDate;
    }

    final List<String> parts = value.split('/');

    if (parts.length != 3) {
      return null;
    }

    final int? day = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) {
      return null;
    }

    return DateTime.tryParse(
      '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}',
    );
  }

  String? _validateTitle(String? value) {
    final String title = value?.trim() ?? '';

    if (title.isEmpty) {
      return 'Please enter an item title.';
    }

    if (title.length < 3) {
      return 'Title must be at least 3 characters.';
    }

    if (title.length > 100) {
      return 'Title must be 100 characters or less.';
    }

    return null;
  }

  String? _validateDescription(String? value) {
    final String description = value?.trim() ?? '';

    if (description.isEmpty) {
      return 'Please enter a description.';
    }

    if (description.length < 10) {
      return 'Description must be at least 10 characters.';
    }

    if (description.length > 500) {
      return 'Description must be 500 characters or less.';
    }

    return null;
  }

  String? _validateLocation(String? value) {
    final String location = value?.trim() ?? '';

    if (location.isEmpty) {
      return 'Please enter a location.';
    }

    if (location.length < 2) {
      return 'Location must be at least 2 characters.';
    }

    if (location.length > 100) {
      return 'Location must be 100 characters or less.';
    }

    return null;
  }

  String? _validateDate(String? value) {
    if (_parseDate(value?.trim() ?? '') == null) {
      return 'Please select a valid date.';
    }

    return null;
  }

  Future<void> _saveChanges() async {
    if (_isSaving) {
      return;
    }

    final FormState? formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final String title = _titleController.text.trim();
    final String description = _descriptionController.text.trim();
    final String location = _locationController.text.trim();
    final String date = _dateController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      await _firestoreService.updateItem(
        itemId: widget.item.id,
        title: title,
        description: description,
        category: _selectedCategory,
        type: _selectedType == LostFoundType.lost ? 'lost' : 'found',
        location: location,
        date: date,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item updated successfully.'),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('EDIT ITEM FIRESTORE ERROR: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to update the item. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Item'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Update your item details',
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Make sure the information is accurate before saving.',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 20),
                _buildSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Item Type',
                        style: AppTextStyles.labelMedium,
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<LostFoundType>(
                        segments: const [
                          ButtonSegment<LostFoundType>(
                            value: LostFoundType.lost,
                            label: Text('Lost'),
                            icon: Icon(Icons.help_outline_rounded),
                          ),
                          ButtonSegment<LostFoundType>(
                            value: LostFoundType.found,
                            label: Text('Found'),
                            icon: Icon(
                              Icons.check_circle_outline_rounded,
                            ),
                          ),
                        ],
                        selected: <LostFoundType>{_selectedType},
                        onSelectionChanged: _isSaving
                            ? null
                            : (Set<LostFoundType> selection) {
                                setState(() {
                                  _selectedType = selection.first;
                                });
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _titleController,
                        enabled: !_isSaving,
                        textInputAction: TextInputAction.next,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Item Title',
                          hintText: 'e.g. Black Backpack',
                          prefixIcon: Icon(
                            Icons.inventory_2_outlined,
                          ),
                        ),
                        validator: _validateTitle,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        enabled: !_isSaving,
                        maxLines: 4,
                        maxLength: 500,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Describe the item',
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(bottom: 52),
                            child: Icon(
                              Icons.description_outlined,
                            ),
                          ),
                          alignLabelWithHint: true,
                        ),
                        validator: _validateDescription,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildSectionCard(
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          prefixIcon: Icon(
                            Icons.category_outlined,
                          ),
                        ),
                        items: ItemCategories.values.map(
                          (String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          },
                        ).toList(),
                        onChanged: _isSaving
                            ? null
                            : (String? value) {
                                if (value == null) {
                                  return;
                                }

                                setState(() {
                                  _selectedCategory = value;
                                });
                              },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _locationController,
                        enabled: !_isSaving,
                        textInputAction: TextInputAction.next,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Location',
                          hintText: 'Where was it lost or found?',
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                          ),
                        ),
                        validator: _validateLocation,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _dateController,
                        enabled: !_isSaving,
                        readOnly: true,
                        onTap: _isSaving ? null : _selectDate,
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(
                            Icons.calendar_today_outlined,
                          ),
                          suffixIcon: Icon(
                            Icons.edit_calendar_outlined,
                          ),
                        ),
                        validator: _validateDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveChanges,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Changes',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: child,
    );
  }
}
