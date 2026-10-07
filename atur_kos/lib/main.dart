import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:atur_kos/screens/splash/splash_screen.dart';
import 'package:atur_kos/screens/auth/welcome_screen.dart';
import 'package:atur_kos/screens/auth/reset_password_screen.dart';
import 'package:atur_kos/models/user_profile.dart';
import 'package:atur_kos/services/auth_service.dart';
import 'package:atur_kos/screens/dashboard/owner_dashboard_screen.dart';
import 'package:atur_kos/screens/dashboard/tenant_dashboard_screen.dart';

// Konfigurasi Supabase Proyek Atur Kos
const String supabaseUrl = 'https://saaavfsgmrghncokwiwy.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNhYWF2ZnNnbXJnaG5jb2t3aXd5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0NzUyNDYsImV4cCI6MjEwNDA1MTI0Nn0.fbgGz9GsaDTy2ptriyvDAAZcTN0rzpidO0DsfDqGDM4';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);

  runApp(const AturKosApp());
}

// Helper getter cepat untuk Supabase Client
final supabase = Supabase.instance.client;

class AturKosApp extends StatelessWidget {
  const AturKosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atur Kos',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E40AF), // Biru modern profesional
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}

/// Widget Penjaga Akses (AuthGate):
/// Memeriksa status login dan mengarahkan pengguna secara otomatis ke
/// Dasbor Pemilik (Owner) atau Dasbor Penghuni (Tenant) sesuai role di PRD.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final authState = snapshot.data;

        // Tangani jika pengguna membuka tautan pemulihan kata sandi dari email
        if (authState?.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }

        final session = authState?.session ?? supabase.auth.currentSession;
        if (session == null) {
          return const WelcomeScreen();
        }

        // Ambil profil pengguna dari database Supabase
        return FutureBuilder<UserProfile>(
          future: AuthService.fetchUserProfile(session.user),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFFF8FAFC),
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF1E40AF)),
                      SizedBox(height: 16),
                      Text(
                        'Memuat data profil & hak akses...',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final userProfile =
                profileSnapshot.data ??
                UserProfile(
                  id: session.user.id,
                  fullName: session.user.email ?? 'Pengguna',
                  email: session.user.email,
                  role: UserRole.tenant,
                );

            // Pengalihan rute 100% murni sesuai hak akses RBAC (Modul 1 PRD)
            if (userProfile.role == UserRole.owner) {
              return OwnerDashboardScreen(
                profile: userProfile,
              );
            } else {
              return TenantDashboardScreen(
                profile: userProfile,
              );
            }
          },
        );
      },
    );
  }
}
