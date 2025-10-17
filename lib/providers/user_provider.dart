// lib/providers/user_provider.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/team_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class UserProvider with ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  List<TeamModel>? _teams;
  List<TeamModel>? get teams => _teams;

  final Completer<void> _initializationCompleter = Completer<void>();
  Future<void> get onInitializationComplete => _initializationCompleter.future;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<UserModel>? _userDocSubscription;
  StreamSubscription<List<TeamModel>>? _teamsSubscription;

  UserProvider() {
    _authSubscription = _authService.user.listen(_onAuthStateChanged);
  }

  // --- NEW METHOD ---
  /// Signs the user out of the application.
  Future<void> signOut() async {
    await _authService.signOut();
  }
  // ----------------

  Future<void> _onAuthStateChanged(User? user) async {
    if (user?.uid == _userModel?.uid && _initializationCompleter.isCompleted) {
      return;
    }

    if (user == null) {
      if (_userModel != null) {
        _userModel = null;
        _teams = null;
        await _userDocSubscription?.cancel();
        await _teamsSubscription?.cancel();
        _userDocSubscription = null;
        _teamsSubscription = null;
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

        await _teamsSubscription?.cancel();
        _teamsSubscription =
            _firestoreService.getTeamsForUser(user.uid).listen((teamsData) {
          _teams = teamsData;
          notifyListeners();
        });
      } catch (e) {
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
    _teamsSubscription?.cancel();
    super.dispose();
  }
}

