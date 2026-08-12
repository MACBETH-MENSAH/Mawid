import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';

/// Central place for talking to Supabase. Screens should go through
/// providers (see AuthProvider), which use this service — screens should
/// not call Supabase.instance.client directly, so backend logic stays
/// in one testable place.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;

  User? get currentUser => client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    // The full_name we pass in metadata is picked up by the
    // handle_new_user() trigger in eventhive_schema.sql, which creates
    // the matching row in `profiles` automatically.
    await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  Future<Profile?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final row = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;
    return Profile.fromJson(row);
  }

  Future<void> updateProfile({
    required String fullName,
    String? phone,
    String? avatarUrl,
    bool? notifyRegistration,
    bool? notifyCheckin,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('Not logged in');

    await client.from('profiles').update({
      'full_name': fullName,
      if (phone != null) 'phone': phone,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (notifyRegistration != null) 'notify_registration': notifyRegistration,
      if (notifyCheckin != null) 'notify_checkin': notifyCheckin,
    }).eq('id', user.id);
  }

  /// Uploads image bytes to the 'avatars' bucket at a path scoped to the
  /// current user (avatars/{userId}/avatar.jpg), then returns its public
  /// URL. Using Uint8List (not dart:io File) so this works identically
  /// on Android, iOS, and web — image_picker's XFile.readAsBytes() gives
  /// us this on every platform, unlike File which doesn't exist on web.
  Future<String> uploadAvatar(Uint8List bytes, {required String fileExt}) async {
    final user = currentUser;
    if (user == null) throw Exception('Not logged in');

    final path = '${user.id}/avatar.$fileExt';
    await client.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true), // overwrite old avatar
    );
    final publicUrl = client.storage.from('avatars').getPublicUrl(path);

    // Cache-busting: the storage path (and therefore the public URL) is
    // identical every time this user uploads a new avatar, since it
    // always overwrites the same file. Flutter's image cache keys purely
    // off the URL string, so without this, a second upload would show
    // the OLD cached image indefinitely even though the file on the
    // server actually changed — this is exactly the bug where the new
    // photo never appeared. Appending a changing query param forces a
    // fresh fetch every time.
    return '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Full account deletion — this must go through a server-side Edge
  /// Function (see supabase/functions/delete-account) rather than
  /// anything the client does directly, because actually removing a
  /// login (auth.users row) requires the service_role key, which can
  /// never be embedded in the app itself. Deleting that row cascades to
  /// remove the profile and everything owned by it.
  Future<void> deleteAccount() async {
    final response = await client.functions.invoke('delete-account');
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}