import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:atur_kos/models/user_profile.dart';

/// Layanan terpusat untuk operasi Autentikasi Supabase di Atur Kos
class AuthService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Memulai alur masuk (sign-in) menggunakan Google OAuth melalui Supabase.
  /// 
  /// Mengembalikan `true` jika proses inisiasi OAuth berhasil dipicu.
  static Future<bool> signInWithGoogle({
    required BuildContext context,
    void Function(bool isLoading)? onLoadingChanged,
  }) async {
    try {
      onLoadingChanged?.call(true);

      // Konfigurasi redirect URL sesuai platform:
      // Di Web: Supabase otomatis mengarahkan ke URL saat ini / origin yang terdaftar di Dashboard
      // Di Android/iOS: Menggunakan skema custom deep-link
      final String? redirectUrl = kIsWeb
          ? null
          : 'io.supabase.aturkos://login-callback';

      final success = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      return success;
    } on AuthException catch (e) {
      if (context.mounted) {
        String errorMessage = e.message;
        if (e.message.toLowerCase().contains('user cancelled') ||
            e.message.toLowerCase().contains('canceled')) {
          errorMessage = 'Proses masuk dengan Google dibatalkan.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return false;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Kendala saat menghubungkan dengan Google: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return false;
    } finally {
      onLoadingChanged?.call(false);
    }
  }

  /// Keluar dari akun saat ini
  static Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Mengambil profil pengguna dari tabel `public.profiles`
  /// Dilengkapi fallback ke metadata autentikasi Supabase.
  static Future<UserProfile> fetchUserProfile(User user) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        return UserProfile.fromMap(
          response,
          fallbackEmail: user.email,
          metadata: user.userMetadata,
        );
      }

      // Jika baris profiles belum ada (misal trigger DB belum jalan),
      // buat instance dari metadata auth dan coba sinkronkan ke DB.
      final fallbackProfile = UserProfile.fromMap(
        {'id': user.id},
        fallbackEmail: user.email,
        metadata: user.userMetadata,
      );

      // Simpan data dasar ke tabel profiles secara background
      await _client.from('profiles').upsert({
        'id': user.id,
        'full_name': fallbackProfile.fullName,
        'role': fallbackProfile.role.value,
        'avatar_url': fallbackProfile.avatarUrl,
        'nomor_wa': fallbackProfile.nomorWa,
      }).catchError((_) => null);

      return fallbackProfile;
    } catch (_) {
      // Fallback aman jika koneksi offline / tabel error
      return UserProfile.fromMap(
        {'id': user.id},
        fallbackEmail: user.email,
        metadata: user.userMetadata,
      );
    }
  }

  /// Memperbarui peran (role) pengguna di database Supabase (owner / tenant)
  static Future<bool> updateUserRole(String userId, UserRole newRole) async {
    try {
      await _client
          .from('profiles')
          .update({'role': newRole.value, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);
      return true;
    } catch (e) {
      debugPrint('Gagal memperbarui peran pengguna: $e');
      return false;
    }
  }
}
