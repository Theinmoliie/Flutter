// lib/UserProfile/generic_profile_field_edit_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skinsafe/providers/skin_profile_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// An enum to define which field we are editing.
enum EditableProfileField { username, dateOfBirth }

class GenericProfileFieldEditPage extends StatefulWidget {
  final EditableProfileField fieldToEdit;

  const GenericProfileFieldEditPage({
    super.key,
    required this.fieldToEdit,
  });

  @override
  State<GenericProfileFieldEditPage> createState() =>
      _GenericProfileFieldEditPageState();
}

class _GenericProfileFieldEditPageState
    extends State<GenericProfileFieldEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profileProvider = context.read<SkinProfileProvider>();
    // Pre-fill the correct initial value based on the field being edited.
    if (widget.fieldToEdit == EditableProfileField.username) {
      _textController.text = profileProvider.username ?? '';
    } else if (widget.fieldToEdit == EditableProfileField.dateOfBirth) {
      _selectedDate = profileProvider.dateOfBirth ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // A single save function that handles both cases.
  Future<void> _saveChanges() async {
    // For text fields, validate the form.
    if (widget.fieldToEdit == EditableProfileField.username &&
        !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    String dbColumnName;
    dynamic dbValue;
    String? localUsername;
    DateTime? localDob;

    // Determine what to save based on the field being edited.
    if (widget.fieldToEdit == EditableProfileField.username) {
      dbColumnName = 'username';
      dbValue = _textController.text.trim();
      localUsername = dbValue;
    } else {
      dbColumnName = 'date_of_birth';
      dbValue = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      localDob = _selectedDate;
    }

    final userId = Supabase.instance.client.auth.currentUser!.id;

    try {
      // Update the single column in Supabase.
      await Supabase.instance.client
          .from('profiles')
          .update({dbColumnName: dbValue}).eq('id', userId);

      // Update the local provider.
      if (mounted) {
        context.read<SkinProfileProvider>().updateUserProfile(
              username: localUsername,
              dob: localDob,
            );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Dynamically builds the UI based on the field.
  Widget _buildEditField() {
    if (widget.fieldToEdit == EditableProfileField.username) {
      return Form(
        key: _formKey,
        child: TextFormField(
          controller: _textController,
          decoration: InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a username';
            }
            return null;
          },
        ),
      );
    } else {
      // Date of Birth field
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Date of Birth'),
        subtitle: Text(_selectedDate == null ? 'Not Set' : DateFormat.yMMMMd().format(_selectedDate!)),
        trailing: const Icon(Icons.calendar_today),
        onTap: () => _selectDate(context),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine the title for the AppBar.
    final String title = widget.fieldToEdit == EditableProfileField.username
        ? 'Edit Username'
        : 'Edit Date of Birth';
        
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildEditField(),
            const Spacer(), // Pushes the button to the bottom
            ElevatedButton(
              onPressed: _isLoading ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_isLoading ? 'Saving...' : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}