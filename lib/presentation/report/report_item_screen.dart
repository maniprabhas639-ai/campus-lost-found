import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/item_categories.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/services/firestore_service.dart';

class ReportItemScreen extends StatefulWidget {
  const ReportItemScreen({super.key});

  @override
  State<ReportItemScreen> createState() => _ReportItemScreenState();
}

class _ReportItemScreenState extends State<ReportItemScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();

  String _selectedType = 'Lost';
  String _selectedCategory = 'Other';

  DateTime? _selectedDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _dateController.dispose();

    super.dispose();
  }

  Future<void> _selectDate() async {
    if (_isSubmitting) {
      return;
    }

    final DateTime now = DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: now,
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
      _dateController.text =
          '${pickedDate.day.toString().padLeft(2, '0')}/'
          '${pickedDate.month.toString().padLeft(2, '0')}/'
          '${pickedDate.year}';
    });
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

  String? _validateDate(String? value) {
    if (_selectedDate == null) {
      return 'Please select a date.';
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

  Future<void> _submitForm() async {
    if (_isSubmitting) {
      return;
    }

    final FormState? formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to report an item.'),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _firestoreService.createItem(
        title: _titleController.text,
        description: _descriptionController.text,
        category: _selectedCategory,
        type: _selectedType.toLowerCase(),
        location: _locationController.text,
        date: _dateController.text,
        ownerId: currentUser.uid,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item reported successfully.'),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('REPORT ITEM FIRESTORE ERROR: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to report item. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Item'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                'Report a Lost or Found Item',
                style: AppTextStyles.headingLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Provide the details below so other students can help.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              Text(
                'Item Type',
                style: AppTextStyles.headingMedium,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'Lost',
                    label: Text('Lost'),
                    icon: Icon(Icons.help_outline),
                  ),
                  ButtonSegment<String>(
                    value: 'Found',
                    label: Text('Found'),
                    icon: Icon(Icons.check_circle_outline),
                  ),
                ],
                selected: <String>{_selectedType},
                onSelectionChanged: _isSubmitting
                    ? null
                    : (Set<String> selection) {
                        setState(() {
                          _selectedType = selection.first;
                        });
                      },
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Item title',
                  hintText: 'e.g. Black Backpack',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: _validateTitle,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: ItemCategories.values.map(
                  (String category) {
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    );
                  },
                ).toList(),
                onChanged: _isSubmitting
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
                controller: _descriptionController,
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.newline,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Describe the item...',
                  prefixIcon: Icon(Icons.description_outlined),
                  alignLabelWithHint: true,
                ),
                validator: _validateDescription,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                enabled: !_isSubmitting,
                readOnly: true,
                onTap: _isSubmitting ? null : _selectDate,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  hintText: 'Select date',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                  suffixIcon: Icon(Icons.arrow_drop_down),
                ),
                validator: _validateDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                enabled: !_isSubmitting,
                textInputAction: TextInputAction.done,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Central Library',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: _validateLocation,
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitForm,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Report',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
