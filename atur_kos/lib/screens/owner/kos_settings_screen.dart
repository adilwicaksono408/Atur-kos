import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atur_kos/services/kos_service.dart';

/// Halaman Pengaturan & Kustomisasi Profil Properti Kos
/// Pemilik dapat menyesuaikan nama kos, alamat, rekening bank, dan nomor kontak secara mandiri.
class KosSettingsScreen extends StatefulWidget {
  final String? kostId;
  final String currentKosName;

  const KosSettingsScreen({
    super.key,
    required this.kostId,
    required this.currentKosName,
  });

  @override
  State<KosSettingsScreen> createState() => _KosSettingsScreenState();
}

class _KosSettingsScreenState extends State<KosSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _namaKosController;
  late TextEditingController _alamatController;
  late TextEditingController _kontakController;
  late TextEditingController _bankController;
  late TextEditingController _rekeningController;
  late TextEditingController _atasNamaController;
  late TextEditingController _kodeKostController;

  String _kodeKost = 'PRINCESS';
  String? _actualKostId;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _namaKosController = TextEditingController(text: widget.currentKosName);
    _alamatController = TextEditingController();
    _kontakController = TextEditingController();
    _bankController = TextEditingController(text: 'BCA');
    _rekeningController = TextEditingController();
    _atasNamaController = TextEditingController();
    _kodeKostController = TextEditingController(text: 'PRINCESS');

    _loadKosData();
  }

  @override
  void dispose() {
    _namaKosController.dispose();
    _alamatController.dispose();
    _kontakController.dispose();
    _bankController.dispose();
    _rekeningController.dispose();
    _atasNamaController.dispose();
    _kodeKostController.dispose();
    super.dispose();
  }

  Future<void> _loadKosData() async {
    final data = await KosService.getKosProfile(widget.kostId);
    if (mounted && data != null) {
      setState(() {
        _actualKostId = data['id']?.toString();
        _namaKosController.text = data['nama_kost']?.toString() ?? widget.currentKosName;
        _alamatController.text = data['alamat']?.toString() ?? '';
        _kontakController.text = data['nomor_kontak']?.toString() ?? '';
        _bankController.text = data['rekening_bank']?.toString() ?? 'BCA';
        _rekeningController.text = data['nomor_rekening']?.toString() ?? '';
        _atasNamaController.text = data['nama_pemilik_rekening']?.toString() ?? '';
        _kodeKost = data['kode_kost']?.toString() ?? 'PRINCESS';
        _kodeKostController.text = _kodeKost;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_actualKostId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Kos tidak ditemukan.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await KosService.updateKosProfile(
      kostId: _actualKostId!,
      namaKost: _namaKosController.text.trim(),
      alamat: _alamatController.text.trim(),
      nomorKontak: _kontakController.text.trim(),
      rekeningBank: _bankController.text.trim(),
      namaPemilikRekening: _atasNamaController.text.trim(),
      kodeKost: _kodeKostController.text.trim().toUpperCase(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(child: Text('Profil & Rekening Kos berhasil diperbarui!')),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true); // Kirim true agar dashboard me-refresh nama kos
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan perubahan. Periksa koneksi Anda.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pengaturan Properti Kos',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E40AF)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // KARTU KODE UNDANGAN KOS
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.qr_code_rounded, color: Color(0xFF1E40AF), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kode Undangan Calon Penghuni',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _kodeKost,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                    color: Color(0xFF1E40AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Color(0xFF1E40AF)),
                            tooltip: 'Salin Kode Undangan',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _kodeKost));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Kode undangan $_kodeKost berhasil disalin!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // SEKSI 1: INFORMASI UMUM PROPERTI
                    const Text(
                      'Informasi Umum Kos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildFieldLabel('Nama Properti Kos'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _namaKosController,
                      decoration: _buildInputDecoration(
                        hint: 'Contoh: Kos Princess',
                        icon: Icons.apartment_rounded,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Nama kos wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Alamat Lengkap Kos'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _alamatController,
                      maxLines: 2,
                      decoration: _buildInputDecoration(
                        hint: 'Jl. Contoh Alamat Kos No. 1, Yogyakarta',
                        icon: Icons.location_on_outlined,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Alamat wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Nomor WhatsApp Admin / Pemilik'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _kontakController,
                      keyboardType: TextInputType.phone,
                      decoration: _buildInputDecoration(
                        hint: '081234567890',
                        icon: Icons.phone_android_rounded,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty ? 'Nomor kontak wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Kode Undangan Kos (Untuk Calon Penghuni)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _kodeKostController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _buildInputDecoration(
                        hint: 'Contoh: PRINCESS',
                        icon: Icons.qr_code_rounded,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Kode undangan wajib diisi';
                        }
                        if (value.trim().length < 3) {
                          return 'Kode undangan minimal 3 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // SEKSI 2: REKENING PEMBAYARAN SEWA (Untuk Smart Billing)
                    const Text(
                      'Rekening Pembayaran Sewa',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Informasi ini akan otomatis muncul pada layar tagihan anak kos saat mereka akan mentransfer uang sewa.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    _buildFieldLabel('Nama Bank / Dompet Digital'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _bankController,
                      decoration: _buildInputDecoration(
                        hint: 'BCA, Mandiri, BRI, BNI, Jago, dll',
                        icon: Icons.account_balance_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Nomor Rekening Bank'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _rekeningController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(
                        hint: '1234567890',
                        icon: Icons.credit_card_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Atas Nama Rekening'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _atasNamaController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _buildInputDecoration(
                        hint: 'Nama Pemilik Rekening (Contoh: Budi Santoso)',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // TOMBOL SIMPAN
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Color(0xFF334155),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF94A3B8)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
    );
  }
}
