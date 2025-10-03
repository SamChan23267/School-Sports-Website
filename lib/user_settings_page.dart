// lib/user_settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'user_profile_page.dart'; // Import the new page

class UserSettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  const UserSettingsPage({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isEditingName = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final userModel = context.read<UserProvider>().userModel;
    _nameController = TextEditingController(text: userModel?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateUserName() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      final userModel = context.read<UserProvider>().userModel;
      final firestoreService = context.read<FirestoreService>();
      final messenger = ScaffoldMessenger.of(context);

      if (userModel != null) {
        try {
          await firestoreService.updateUserName(
              userModel.uid, _nameController.text);
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Your name has been updated.'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _isEditingName = false;
          });
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Error updating name: $e'),
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

  Future<void> _deleteAccount() async {
    final userModel = context.read<UserProvider>().userModel;
    if (userModel == null) return;

    final confirmController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'This action is permanent and cannot be undone. All your data, including team memberships and followed teams, will be deleted.'),
            const SizedBox(height: 16),
            const Text(
                'Please type "DELETE" below to confirm.'),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'DELETE',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: confirmController,
            builder: (context, value, child) {
              return TextButton(
                onPressed: value.text == 'DELETE'
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: const Text('DELETE', style: TextStyle(color: Colors.red)),
              );
            },
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final authService = context.read<AuthService>();
      final firestoreService = context.read<FirestoreService>();
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      try {
        // First delete Firestore data, then the auth account
        await firestoreService.deleteUser(userModel.uid);
        await authService.deleteCurrentUserAccount();
        
        messenger.showSnackBar(
          const SnackBar(content: Text('Your account has been deleted.')),
        );
        // Pop all the way back to the landing page, which will refresh.
        navigator.popUntil((route) => route.isFirst);

      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userModel = context.watch<UserProvider>().userModel;

    if (userModel == null) {
      // This should not happen if navigated correctly, but as a fallback.
      return Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: Text('Please log in to view settings.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profile Section
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account Information',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    Center(
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: NetworkImage(userModel.photoURL),
                        child: userModel.photoURL.isEmpty
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      readOnly: !_isEditingName,
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        helperText: 'This is the name other users will see in the app.',
                        suffixIcon: IconButton(
                          icon: Icon(_isEditingName ? Icons.clear : Icons.edit),
                          onPressed: () {
                            setState(() {
                              _isEditingName = !_isEditingName;
                              if (!_isEditingName) {
                                // Reset to original name if cancelled
                                _nameController.text = userModel.displayName;
                              }
                            });
                          },
                        ),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? 'Name cannot be empty' : null,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(userModel.email),
                    ),
                    const SizedBox(height: 16),
                    if (_isEditingName)
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _updateUserName,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Save Name'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Link to User Profile Page
          Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('My Profile'),
              subtitle: const Text('Update personal, emergency, and medical info.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfilePage(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // App Settings Section
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('App Settings',
                        style: Theme.of(context).textTheme.titleLarge),
                  SwitchListTile(
                    title: const Text('Dark Mode'),
                    secondary: Icon(
                      widget.themeMode == ThemeMode.dark
                          ? Icons.nightlight_round
                          : Icons.wb_sunny,
                    ),
                    value: widget.themeMode == ThemeMode.dark,
                    onChanged: (value) => widget.onToggleTheme(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Danger Zone
          Card(
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Danger Zone',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                    leading: Icon(Icons.delete_forever,
                        color: Theme.of(context).colorScheme.error),
                    title: const Text('Delete Account'),
                    subtitle: const Text(
                        'Permanently delete your account and all associated data.'),
                    onTap: _deleteAccount,
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

