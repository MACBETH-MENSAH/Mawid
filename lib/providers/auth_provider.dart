import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/profile.dart';
import '../services/supabase_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-wide auth state. Wrap the app in a ChangeNotifierProvider for this
/// class (see main.dart) — screens read `context.watch<AuthProvider>()`
/// instead of calling Supabase directly.
class AuthProvider with ChangeNotifier {
  final _service = SupabaseService.instance;

  AuthStatus status = AuthStatus.unknown;
  Profile? profile;
  String? errorMessage;
  bool isLoading = false;

  AuthProvider() {
    _init();
  }

  void _init() {
    // Pick up whatever session Supabase already restored from disk.
    status = _service.isLoggedIn
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    if (status == AuthStatus.authenticated) {
      _loadProfile();
    }

    _service.authStateChanges.listen((state) {
      final loggedIn = state.session != null;
      status = loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated;
      if (loggedIn) {
        _loadProfile();
      } else {
        profile = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadProfile() async {
    profile = await _service.fetchCurrentProfile();
    notifyListeners();
  }

  /// Public wrapper so screens (Edit Profile) can force a re-fetch after
  /// changing profile fields, without exposing _loadProfile directly.
  Future<void> refreshProfile() => _loadProfile();

  Future<void> updateProfileFields({
    required String fullName,
    String? phone,
    String? avatarUrl,
    bool? notifyRegistration,
    bool? notifyCheckin,
  }) async {
    await _service.updateProfile(
      fullName: fullName,
      phone: phone,
      avatarUrl: avatarUrl,
      notifyRegistration: notifyRegistration,
      notifyCheckin: notifyCheckin,
    );
    await _loadProfile(); // pick up the change immediately, app-wide
  }

  /// Uploads a new avatar image and saves its URL to the profile in one
  /// step, so screens don't need to juggle the upload result themselves.
  Future<void> uploadAndSaveAvatar(Uint8List bytes, {required String fileExt}) async {
    final url = await _service.uploadAvatar(bytes, fileExt: fileExt);
    final current = profile;
    if (current == null) return;
    await updateProfileFields(fullName: current.fullName, avatarUrl: url);
  }

  /// Deletes the account for real (see supabase_service.dart /
  /// supabase/functions/delete-account for why this has to go through a
  /// server-side function). Signs the local session out afterward since
  /// the account no longer exists to be signed into.
  Future<void> deleteAccount() async {
    await _service.deleteAccount();
    await signOut();
  }

  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
  }) => _run(() => _service.signUp(
    fullName: fullName,
    email: email,
    password: password,
  ));

  Future<bool> signIn({
    required String email,
    required String password,
  }) => _run(() => _service.signIn(email: email, password: password));

  Future<void> signOut() async {
    await _service.signOut();
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      errorMessage = _friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('User already registered')) {
      return 'An account with this email already exists.';
    }
    return 'Something went wrong. Please try again.';
  }
}