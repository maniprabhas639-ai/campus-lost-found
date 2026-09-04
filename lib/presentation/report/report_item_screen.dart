import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/constants/item_categories.dart';
import '../../core/theme/app_colors.dart';
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _buildIntroSection(),
              const SizedBox(height: 24),
              _buildSectionTitle('What are you reporting?'),
              const SizedBox(height: 10),
              _buildTypeSelector(),
              const SizedBox(height: 24),
              _buildSectionTitle('Item details'),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              _buildHelpfulTip(),
              const SizedBox(height: 24),
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

  Widget _buildIntroSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.add_box_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report a Lost or Found Item',
                  style: AppTextStyles.headingSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  'Provide accurate details so other students can help.',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.headingSmall,
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _TypeOptionCard(
            title: 'Lost',
            subtitle: 'I lost this item',
            icon: Icons.help_outline_rounded,
            isSelected: _selectedType == 'Lost',
            color: AppColors.warning,
            backgroundColor: AppColors.warningSoft,
            onTap: _isSubmitting
                ? null
                : () {
                    setState(() {
                      _selectedType = 'Lost';
                    });
                  },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeOptionCard(
            title: 'Found',
            subtitle: 'I found this item',
            icon: Icons.check_circle_outline_rounded,
            isSelected: _selectedType == 'Found',
            color: AppColors.success,
            backgroundColor: AppColors.successSoft,
            onTap: _isSubmitting
                ? null
                : () {
                    setState(() {
                      _selectedType = 'Found';
                    });
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildHelpfulTip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lightbulb_outline_rounded,
            size: 19,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tip: Include specific details such as color, '
              'brand, or identifying marks when possible.',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeOptionCard extends StatelessWidget {
  const _TypeOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final Color backgroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? backgroundColor : AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.35)
                  : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.surface
                      : AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 11),
              Text(
                title,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected
                      ? color
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}