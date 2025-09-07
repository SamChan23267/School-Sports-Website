import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class UserProvider with ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  final Completer<void> _initializationCompleter = Completer<void>();
  Future<void> get onInitializationComplete => _initializationCompleter.future;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel>? _userDocSubscription;

  UserProvider() {
    _authSubscription = _authService.user.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user?.uid == _userModel?.uid && _initializationCompleter.isCompleted) {
      return;
    }

    if (user == null) {
      if (_userModel != null) {
        _userModel = null;
        await _userDocSubscription?.cancel();
        _userDocSubscription = null;
        notifyListeners();
      }
    } else {
      try {
        await _firestoreService.createUserProfile(user);

        await _userDocSubscription?.cancel();
        _userDocSubscription =
            _firestoreService.getUserStream(user.uid).listen((userDoc) {
          _userModel = userDoc;
          notifyListeners();
        });
      } catch (e) {
        // This is a useful error log to keep.
        print("UserProvider: CRITICAL ERROR during user profile processing: $e");
      }
    }

    if (!_initializationCompleter.isCompleted) {
      _initializationCompleter.complete();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userDocSubscription?.cancel();
    super.dispose();
  }
}

