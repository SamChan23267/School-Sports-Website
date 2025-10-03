// lib/user_profile_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emergencyContactNameController;
  late TextEditingController _emergencyContactPhoneController;
  late TextEditingController _medicalConditionsController;
  DateTime? _birthday;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final userModel = context.read<UserProvider>().userModel;
    _fullNameController = TextEditingController(text: userModel?.fullName ?? '');
    _phoneController = TextEditingController(text: userModel?.phoneNumber ?? '');
    _birthday = userModel?.birthday?.toDate();
    _emergencyContactNameController =
        TextEditingController(text: userModel?.emergencyContactName ?? '');
    _emergencyContactPhoneController =
        TextEditingController(text: userModel?.emergencyContactPhone ?? '');
    _medicalConditionsController =
        TextEditingController(text: userModel?.medicalConditions ?? '');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    _medicalConditionsController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime.now().subtract(const Duration(days: 16 * 365)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && pickedDate != _birthday) {
      setState(() {
        _birthday = pickedDate;
      });
    }
  }

  Future<void> _saveProfileInfo() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final userModel = context.read<UserProvider>().userModel;
      final firestoreService = context.read<FirestoreService>();
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      if (userModel != null) {
        try {
          await firestoreService.updateUserProfileInfo(
            uid: userModel.uid,
            fullName: _fullNameController.text,
            birthday: _birthday,
            phoneNumber: _phoneController.text,
            contactName: _emergencyContactNameController.text,
            contactPhone: _emergencyContactPhoneController.text,
            medicalNotes: _medicalConditionsController.text,
          );
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Your information has been saved.'),
              backgroundColor: Colors.green,
            ),
          );
          navigator.pop();
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error saving information: $e'),
              backgroundColor: Colors.red,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Personal Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name (Legal Name)',
                        icon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                     ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.cake_outlined),
                      title: const Text('Birthday'),
                      subtitle: Text(
                        _birthday == null
                            ? 'Not set'
                            : DateFormat.yMMMMd().format(_birthday!),
                      ),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: _pickBirthday,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number (Optional)',
                        icon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Emergency Contact Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Contact',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emergencyContactNameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        icon: Icon(Icons.person_outline),
                      ),
                       validator: (value) {
                        if (_emergencyContactPhoneController.text.isNotEmpty && (value == null || value.isEmpty)) {
                          return 'Please enter a name if providing a number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emergencyContactPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        icon: Icon(Icons.contact_phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (_emergencyContactNameController.text.isNotEmpty && (value == null || value.isEmpty)) {
                          return 'Please enter a number if providing a name';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Medical Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Medical Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please list any important medical conditions, allergies, or medications. This information may be made accessible to authorized staff in an emergency.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _medicalConditionsController,
                      decoration: const InputDecoration(
                        labelText: 'Conditions, Allergies, etc. (Optional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 5,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveProfileInfo,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Save Information'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

