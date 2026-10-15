import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:atur_kos/screens/auth/login_screen.dart';

/// Halaman Pendaftaran Akun Atur Kos
/// Mendukung pendaftaran Penghuni (Tenant) dengan Kode Undangan
/// dan pendaftaran Pemilik Kos Baru (Multi-Tenant Owner)
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Tipe Pendaftaran: 'tenant' (Penghuni) atau 'owner' (Pemilik Kos Baru)
  String _selectedRole = 'tenant';

  // Controller Bersama
  final _namaController = TextEditingController();
  final _waController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Controller Khusus Penghuni
  final _kodeKostController = TextEditingController();

  // Controller Khusus Pemilik Kos Baru
  final _namaKostController = TextEditingController();
  final _alamatKostController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _namaController.dispose();
    _waController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _kodeKostController.dispose();
    _namaKostController.dispose();
    _alamatKostController.dispose();
    super.dispose();
  }

  // Format nomor WhatsApp ke format E.164 (628xxx)
  String _formatNomorWa(String rawNumber) {
    String clean = rawNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) {
      clean = '62${clean.substring(1)}';
    } else if (clean.startsWith('8')) {
      clean = '62$clean';
    }
    return clean;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final nama = _namaController.text.trim();
      final nomorWa = _formatNomorWa(_waController.text.trim());

      // Siapkan payload metadata sesuai role
      final Map<String, dynamic> userMetadata = {
        'full_name': nama,
        'nomor_wa': nomorWa,
        'role': _selectedRole,
      };

      if (_selectedRole == 'tenant') {
        // Jika Penghuni: sertakan kode undangan kos
        final kode = _kodeKostController.text.trim().toUpperCase();
        userMetadata['kode_kost'] = kode;
      } else {
        // Jika Pemilik Kos Baru: sertakan nama & alamat properti kosnya
        userMetadata['nama_kost'] = _namaKostController.text.trim();
        userMetadata['alamat_kost'] = _alamatKostController.text.trim();
      }

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: userMetadata,
      );

      if (mounted) {
        if (response.user != null) {
          final isOwner = _selectedRole == 'owner';
          final roleName = isOwner ? 'Pemilik Kos' : 'Penghuni Kos';
          final requiresConfirmation = response.session == null;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(
                    requiresConfirmation
                        ? Icons.mark_email_read_rounded
                        : Icons.check_circle_rounded,
                    color: requiresConfirmation
                        ? const Color(0xFF1E40AF)
                        : const Color(0xFF059669),
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      requiresConfirmation
                          ? 'Konfirmasi Email Anda'
                          : (isOwner ? 'Kos Baru: Wajib Verifikasi' : 'Pendaftaran Berhasil'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pendaftaran akun $roleName atas nama $nama berhasil!',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  if (requiresConfirmation) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFF1E40AF), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Email konfirmasi telah dikirim ke:\n$email',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E3A8A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isOwner
                          ? 'Silakan konfirmasi email Anda terlebih dahulu, lalu masuk ke aplikasi untuk langsung mengajukan dokumen verifikasi kos ke Super Admin.'
                          : 'Silakan buka kotak masuk (inbox atau spam) email Anda dan klik tautan konfirmasi untuk membuktikan bahwa email tersebut adalah milik Anda sebelum masuk.',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                    ),
                  ] else ...[
                    Text(
                      isOwner
                          ? 'Selamat! Akun pemilik untuk kos "${_namaKostController.text.trim()}" telah dibuat.\n\nLangkah Wajib Selanjutnya:\nSilakan masuk ke aplikasi dan langsung lengkapi foto KTP serta foto bangunan kos untuk pengajuan verifikasi ke Super Admin.'
                          : 'Akun penghuni atas nama $nama berhasil terdaftar.\n\nStatus saat ini: "Menunggu Alokasi Kamar oleh Pemilik Kos".',
                      style: const TextStyle(height: 1.4, color: Color(0xFF475569)),
                    ),
                  ],
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isOwner ? 'Masuk & Ajukan Verifikasi' : 'Ke Halaman Masuk'),
                ),
              ],
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kendala: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTenant = _selectedRole == 'tenant';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Buat Akun Atur Kos',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pilih peran Anda untuk mendapatkan dasbor operasional yang sesuai.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),

                // TOGGLE SELEKSI PERAN (PENGHUNI VS PEMILIK KOS BARU)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'tenant'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isTenant ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: isTenant
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person_rounded,
                                  size: 18,
                                  color: isTenant ? theme.colorScheme.primary : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Penghuni Kos',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isTenant ? FontWeight.bold : FontWeight.w500,
                                      color: isTenant ? theme.colorScheme.primary : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedRole = 'owner'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !isTenant ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: !isTenant
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.business_rounded,
                                  size: 18,
                                  color: !isTenant ? theme.colorScheme.primary : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Daftarkan Kos Baru',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: !isTenant ? FontWeight.bold : FontWeight.w500,
                                      color: !isTenant ? theme.colorScheme.primary : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // FIELD KHUSUS PENGHUNI: KODE UNDANGAN KOS
                if (isTenant) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.link_rounded, color: Color(0xFF1E40AF), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Kode Undangan Kos',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Wajib Diisi',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Masukkan kode undangan kos yang Anda dapatkan dari pemilik atau pengelola kos Anda:',
                          style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _kodeKostController,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            hintText: 'Contoh: KOSKU123',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF93C5FD)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF93C5FD)),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Kode undangan kos tidak boleh kosong';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // FIELD KHUSUS PEMILIK KOS BARU: NAMA & ALAMAT KOS
                if (!isTenant) ...[
                  _buildFieldLabel(theme, 'Nama Properti Kos Baru'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _namaKostController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _buildInputDecoration(
                      hint: 'Contoh: Kos Melati Asri',
                      icon: Icons.holiday_village_rounded,
                    ),
                    validator: (value) {
                      if (!isTenant && (value == null || value.trim().isEmpty)) {
                        return 'Nama kos wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFieldLabel(theme, 'Alamat Lengkap Kos'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _alamatKostController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _buildInputDecoration(
                      hint: 'Jl. Kaliurang KM 5, Yogyakarta',
                      icon: Icons.location_on_outlined,
                    ),
                    validator: (value) {
                      if (!isTenant && (value == null || value.trim().isEmpty)) {
                        return 'Alamat kos wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // FIELD IDENTITAS AKUN
                _buildFieldLabel(theme, isTenant ? 'Nama Lengkap Penghuni' : 'Nama Lengkap Pemilik'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _namaController,
                  textCapitalization: TextCapitalization.words,
                  decoration: _buildInputDecoration(
                    hint: isTenant ? 'Contoh: Dimas Aditya' : 'Contoh: Budi Santoso',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama lengkap wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildFieldLabel(theme, 'Nomor WhatsApp Aktif'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _waController,
                  keyboardType: TextInputType.phone,
                  decoration: _buildInputDecoration(
                    hint: '081234567890',
                    icon: Icons.phone_android_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nomor WhatsApp wajib diisi untuk notifikasi';
                    }
                    if (value.trim().length < 10) {
                      return 'Nomor WhatsApp minimal 10 digit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildFieldLabel(theme, 'Alamat Email (Untuk Login)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _buildInputDecoration(
                    hint: 'nama@email.com',
                    icon: Icons.email_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email wajib diisi';
                    }
                    if (!value.contains('@')) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                _buildFieldLabel(theme, 'Kata Sandi (Min. 8 Karakter)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Masukkan kata sandi',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF94A3B8),
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kata sandi wajib diisi';
                    }
                    if (value.length < 8) {
                      return 'Kata sandi minimal 8 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // TOMBOL SUBMIT
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isTenant ? 'Daftar Sebagai Penghuni' : 'Daftarkan Kos & Buat Akun',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 20),

                // LINK KE LOGIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Sudah memiliki akun? ', style: TextStyle(color: Color(0xFF64748B))),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Masuk di Sini',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(ThemeData theme, String label) {
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF334155),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}
