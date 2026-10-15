import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:atur_kos/models/kost_model.dart';
import 'package:atur_kos/services/kos_service.dart';

/// Halaman Onboarding & Pengaturan Properti Kos (PRD v2.0.0 Modul 2)
/// Dilengkapi:
/// 1. Identitas Kos & Rekening Pembayaran
/// 2. Dual-Mode Geolocation Picker (Opsi A: GPS 1-Klik & Opsi B: Koordinat Manual / Peta)
/// 3. Dokumen Fisik Verifikasi (Foto KTP Pemilik & Foto Fisik Bangunan)
/// 4. Integrasi Status Verifikasi Super Admin (Pending / Active / Rejected)
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
  late TextEditingController _kodeKostController;

  // Rekening Pembayaran
  late TextEditingController _bankController;
  late TextEditingController _rekeningController;
  late TextEditingController _atasNamaController;

  // Geolocation Dual-Mode (PRD v2.0.0 Modul 2)
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _googleMapsUrlController;

  // Dokumen Verifikasi Fisik
  late TextEditingController _fotoBangunanUrlController;
  late TextEditingController _dokumenKtpUrlController;

  String _kodeKost = '-';
  String? _actualKostId;
  String _statusVerifikasi = 'pending_verification';
  String? _catatanVerifikasiAdmin;
  String _tier = 'starter';
  int _maxRooms = 5;

  final ImagePicker _picker = ImagePicker();
  Uint8List? _fotoBangunanBytes;
  Uint8List? _dokumenKtpBytes;
  bool _isUploadingBangunan = false;
  bool _isUploadingKtp = false;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDetectingGps = false;

  @override
  void initState() {
    super.initState();
    _namaKosController = TextEditingController(text: widget.currentKosName);
    _alamatController = TextEditingController();
    _kontakController = TextEditingController();
    _kodeKostController = TextEditingController();

    _bankController = TextEditingController(text: 'BCA');
    _rekeningController = TextEditingController();
    _atasNamaController = TextEditingController();

    _latitudeController = TextEditingController();
    _longitudeController = TextEditingController();
    _googleMapsUrlController = TextEditingController();

    _fotoBangunanUrlController = TextEditingController();
    _dokumenKtpUrlController = TextEditingController();

    _loadKosData();
  }

  @override
  void dispose() {
    _namaKosController.dispose();
    _alamatController.dispose();
    _kontakController.dispose();
    _kodeKostController.dispose();

    _bankController.dispose();
    _rekeningController.dispose();
    _atasNamaController.dispose();

    _latitudeController.dispose();
    _longitudeController.dispose();
    _googleMapsUrlController.dispose();

    _fotoBangunanUrlController.dispose();
    _dokumenKtpUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadKosData() async {
    final user = Supabase.instance.client.auth.currentUser;
    final userMeta = user?.userMetadata;
    final metaNamaKos = userMeta?['nama_kost']?.toString().trim();
    final metaAlamatKos = userMeta?['alamat_kost']?.toString().trim();
    final metaNomorWa = userMeta?['nomor_wa']?.toString().trim();

    String? targetKostId = widget.kostId;
    if (user != null && metaNamaKos != null && metaNamaKos.isNotEmpty) {
      targetKostId = await KosService.ensureOwnerKosProfile(
        userId: user.id,
        userMetadata: userMeta,
        currentKostId: widget.kostId,
      );
    }

    final data = await KosService.getKosProfile(targetKostId);
    if (mounted && data != null) {
      final dbNamaKos = data['nama_kost']?.toString();
      final shouldUseMetaName = (metaNamaKos != null &&
          metaNamaKos.isNotEmpty &&
          (dbNamaKos == null || dbNamaKos.isEmpty));

      setState(() {
        _actualKostId = data['id']?.toString() ?? targetKostId;
        _namaKosController.text = shouldUseMetaName
            ? metaNamaKos
            : (dbNamaKos ?? widget.currentKosName);
        _alamatController.text = shouldUseMetaName && (metaAlamatKos != null && metaAlamatKos.isNotEmpty)
            ? metaAlamatKos
            : (data['alamat']?.toString() ?? metaAlamatKos ?? '');
        _kontakController.text = shouldUseMetaName && (metaNomorWa != null && metaNomorWa.isNotEmpty)
            ? metaNomorWa
            : (data['nomor_kontak']?.toString() ?? metaNomorWa ?? '');
        _bankController.text = data['rekening_bank']?.toString() ?? 'BCA';
        _rekeningController.text = data['nomor_rekening']?.toString() ?? '';
        _atasNamaController.text = data['nama_pemilik_rekening']?.toString() ?? '';
        _kodeKost = data['kode_kost']?.toString() ?? '-';
        _kodeKostController.text = _kodeKost;

        // Field v2.0.0
        if (data['latitude'] != null) {
          _latitudeController.text = data['latitude'].toString();
        }
        if (data['longitude'] != null) {
          _longitudeController.text = data['longitude'].toString();
        }
        String mapsUrl = data['google_maps_url']?.toString() ?? '';
        if (mapsUrl.isEmpty && data['latitude'] != null && data['longitude'] != null) {
          mapsUrl = 'https://maps.google.com/?q=${data['latitude']},${data['longitude']}';
        }
        _googleMapsUrlController.text = mapsUrl;
        final fotoUrl = data['foto_bangunan_url']?.toString() ?? '';
        _fotoBangunanUrlController.text = fotoUrl;
        if (fotoUrl.startsWith('data:image')) {
          try {
            _fotoBangunanBytes = base64Decode(fotoUrl.split(',').last);
          } catch (_) {}
        }

        final ktpUrl = data['dokumen_ktp_url']?.toString() ?? '';
        _dokumenKtpUrlController.text = ktpUrl;
        if (ktpUrl.startsWith('data:image')) {
          try {
            _dokumenKtpBytes = base64Decode(ktpUrl.split(',').last);
          } catch (_) {}
        }

        _statusVerifikasi = data['status_verifikasi']?.toString() ?? 'pending_verification';
        _catatanVerifikasiAdmin = data['catatan_verifikasi_admin']?.toString();
        _tier = data['tier']?.toString() ?? 'starter';
        _maxRooms = (data['max_rooms'] as int?) ?? 5;

        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ===========================================================================
  // DUAL-MODE GEOLOCATION ENGINE (PRD v2.0.0 Modul 2)
  // ===========================================================================

  /// Deteksi Lokasi Otomatis via GPS Perangkat (1-Klik Cepat dengan Timeout)
  Future<void> _detectCurrentGpsLocation() async {
    setState(() => _isDetectingGps = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Periksa ketersediaan GPS dengan batas waktu 3 detik
      final serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 3),
        onTimeout: () => true,
      );
      if (!serviceEnabled) {
        _showGpsFallbackSnackbar(
          'Layanan GPS belum aktif. Silakan langsung tempelkan tautan Google Maps kos Anda di kolom bawah.',
        );
        return;
      }

      // 2. Periksa & Minta Izin Lokasi
      LocationPermission permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 3),
        onTimeout: () => LocationPermission.unableToDetermine,
      );
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 6),
          onTimeout: () => LocationPermission.denied,
        );
        if (permission == LocationPermission.denied) {
          _showGpsFallbackSnackbar(
            'Izin lokasi tidak diberikan. Cukup tempelkan tautan Google Maps kos Anda di kolom bawah.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showGpsFallbackSnackbar(
          'Izin lokasi dinonaktifkan di browser. Silakan tempelkan tautan Google Maps kos Anda di kolom bawah.',
        );
        return;
      }

      // 3. Ambil Posisi GPS (Gunakan accuracy medium & timeout 6 detik agar tidak macet di Chrome)
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      ).timeout(
        const Duration(seconds: 6),
      );

      final lat = position.latitude.toStringAsFixed(6);
      final lng = position.longitude.toStringAsFixed(6);
      final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';

      setState(() {
        _latitudeController.text = lat;
        _longitudeController.text = lng;
        _googleMapsUrlController.text = mapsUrl;
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text('📍 Lokasi berhasil dideteksi! Koordinat: $lat, $lng'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error detect GPS: $e');
      _showGpsFallbackSnackbar(
        'GPS tidak merespons atau sinyal lemah. Silakan langsung tempelkan tautan Google Maps di kolom bawah.',
      );
    } finally {
      if (mounted) {
        setState(() => _isDetectingGps = false);
      }
    }
  }

  void _showGpsFallbackSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFD97706),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Buka Google Maps untuk Verifikasi atau Pencarian Lokasi
  Future<void> _openGoogleMapsPreview() async {
    String url = _googleMapsUrlController.text.trim();
    final lat = _latitudeController.text.trim();
    final lng = _longitudeController.text.trim();

    if (url.isEmpty && lat.isNotEmpty && lng.isNotEmpty) {
      url = 'https://maps.google.com/?q=$lat,$lng';
    }

    if (url.isEmpty) {
      // Jika belum ada tautan, bantu buka Google Maps berdasarkan nama & alamat kos
      final query = '${_namaKosController.text.trim()} ${_alamatController.text.trim()}'.trim();
      if (query.isNotEmpty) {
        url = 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}';
      } else {
        url = 'https://maps.google.com';
      }
    }

    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: url));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tautan disalin ke clipboard!'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tautan disalin ke clipboard!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ===========================================================================
  // SIMPAN DATA PROPERTI KOS
  // ===========================================================================

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_actualKostId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Kos tidak ditemukan.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    double? lat = double.tryParse(_latitudeController.text.trim());
    double? lng = double.tryParse(_longitudeController.text.trim());
    String mapsUrl = _googleMapsUrlController.text.trim();

    // Otomatis ekstrak lat/lng jika user menempelkan link Google Maps berkoordinat
    if ((lat == null || lng == null) && mapsUrl.isNotEmpty) {
      final reg1 = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
      final match1 = reg1.firstMatch(mapsUrl);
      if (match1 != null) {
        lat = double.tryParse(match1.group(1)!);
        lng = double.tryParse(match1.group(2)!);
      } else {
        final reg2 = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
        final match2 = reg2.firstMatch(mapsUrl);
        if (match2 != null) {
          lat = double.tryParse(match2.group(1)!);
          lng = double.tryParse(match2.group(2)!);
        }
      }
    }

    if (mapsUrl.isEmpty && lat != null && lng != null) {
      mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
    }

    // Jika properti sebelumnya ditolak, simpan ulang akan mengubah status menjadi pending_verification
    String newStatus = _statusVerifikasi;
    if (newStatus == 'rejected') {
      newStatus = 'pending_verification';
    }

    try {
      final success = await KosService.updateKosProfile(
        kostId: _actualKostId!,
        namaKost: _namaKosController.text.trim(),
        alamat: _alamatController.text.trim(),
        nomorKontak: _kontakController.text.trim(),
        rekeningBank: _bankController.text.trim(),
        namaPemilikRekening: _atasNamaController.text.trim(),
        kodeKost: _kodeKostController.text.trim().toUpperCase(),
        latitude: lat,
        longitude: lng,
        googleMapsUrl: mapsUrl.isNotEmpty ? mapsUrl : null,
        fotoBangunanUrl: _fotoBangunanUrlController.text.trim().isNotEmpty
            ? _fotoBangunanUrlController.text.trim()
            : null,
        dokumenKtpUrl: _dokumenKtpUrlController.text.trim().isNotEmpty
            ? _dokumenKtpUrlController.text.trim()
            : null,
        statusVerifikasi: newStatus,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      newStatus == 'pending_verification'
                          ? 'Profil & Dokumen berhasil disimpan! Pengajuan verifikasi telah dikirim ke Super Admin.'
                          : 'Profil kos & geolokasi berhasil diperbarui!',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          navigator.pop(true);
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Gagal menyimpan perubahan. Periksa koneksi Anda.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        if (e.toString().contains('DUPLICATE_KODE_KOST')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
                  SizedBox(width: 8),
                  Text('Kode Sudah Digunakan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              content: Text(
                'Kode undangan "${_kodeKostController.text.trim().toUpperCase()}" sudah dipakai oleh pemilik kos lain. Silakan ubah kode menjadi kombinasi lain yang unik agar calon penghuni tidak salah masuk properti.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E40AF),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Ganti Kode Lain'),
                ),
              ],
            ),
          );
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Terjadi kendala saat menyimpan: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _pickImage({
    required ImageSource source,
    required bool isBangunan,
  }) async {
    try {
      if (isBangunan) {
        setState(() => _isUploadingBangunan = true);
      } else {
        setState(() => _isUploadingKtp = true);
      }

      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 75,
      );

      if (picked == null) {
        if (mounted) {
          setState(() {
            if (isBangunan) {
              _isUploadingBangunan = false;
            } else {
              _isUploadingKtp = false;
            }
          });
        }
        return;
      }

      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      String finalUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';

      // Coba upload ke Supabase Storage (bucket: 'verification-docs') jika tersedia
      try {
        final prefix = isBangunan ? 'bangunan' : 'ktp';
        final fileName = '${prefix}_${_actualKostId ?? "kos"}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final path = 'verifikasi/$fileName';
        await Supabase.instance.client.storage
            .from('verification-docs')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: mimeType, upsert: true),
            );
        final publicUrl = Supabase.instance.client.storage
            .from('verification-docs')
            .getPublicUrl(path);
        finalUrl = publicUrl;
      } catch (storageError) {
        debugPrint('Storage bucket fallback to Base64: $storageError');
      }

      if (mounted) {
        setState(() {
          if (isBangunan) {
            _fotoBangunanBytes = bytes;
            _fotoBangunanUrlController.text = finalUrl;
            _isUploadingBangunan = false;
          } else {
            _dokumenKtpBytes = bytes;
            _dokumenKtpUrlController.text = finalUrl;
            _isUploadingKtp = false;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isBangunan ? 'Foto bangunan kos berhasil dipilih!' : 'Foto KTP pemilik berhasil dipilih!'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error pick image: $e');
      if (mounted) {
        setState(() {
          if (isBangunan) {
            _isUploadingBangunan = false;
          } else {
            _isUploadingKtp = false;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removeImage({required bool isBangunan}) {
    setState(() {
      if (isBangunan) {
        _fotoBangunanBytes = null;
        _fotoBangunanUrlController.clear();
      } else {
        _dokumenKtpBytes = null;
        _dokumenKtpUrlController.clear();
      }
    });
  }

  Widget _buildImageWidget(String url, Uint8List? localBytes) {
    if (localBytes != null) {
      return Image.memory(
        localBytes,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    }
    if (url.startsWith('data:image')) {
      try {
        final bytes = base64Decode(url.split(',').last);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
        );
      } catch (_) {}
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (ctx, err, stack) => Container(
        color: Colors.grey.shade100,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
      ),
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String currentUrl,
    required Uint8List? localBytes,
    required bool isUploading,
    required VoidCallback onPickCamera,
    required VoidCallback onPickGallery,
    required VoidCallback onRemove,
    required VoidCallback onPreview,
  }) {
    final hasImage = currentUrl.isNotEmpty || localBytes != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasImage ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF1E40AF), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              if (hasImage)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Terlampir',
                        style: TextStyle(fontSize: 10, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (isUploading)
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E40AF)),
                  SizedBox(height: 12),
                  Text('Memproses foto...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                ],
              ),
            )
          else if (hasImage)
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      SizedBox(
                        height: 160,
                        width: double.infinity,
                        child: _buildImageWidget(currentUrl, localBytes),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: ElevatedButton.icon(
                          onPressed: onPreview,
                          icon: const Icon(Icons.fullscreen_rounded, size: 16),
                          label: const Text('Perbesar', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.65),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPickCamera,
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Kamera', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          foregroundColor: const Color(0xFF1E40AF),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPickGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Galeri', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          foregroundColor: const Color(0xFF1E40AF),
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      tooltip: 'Hapus Foto',
                    ),
                  ],
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 36, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilih foto dari kamera atau galeri perangkat',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: onPickCamera,
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Ambil dari Kamera'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E40AF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: onPickGallery,
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Buka Galeri'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF1E40AF),
                          side: const BorderSide(color: Color(0xFF1E40AF)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showImagePreview(String title, String url) {
    if (url.trim().isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: url.startsWith('data:image')
                    ? Image.memory(
                        base64Decode(url.split(',').last),
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      )
                    : Image.network(
                        url,
                        height: 300,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image, size: 36, color: Colors.grey),
                              const SizedBox(height: 6),
                              Text('Tautan gambar: $url',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, color: Colors.blue)),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kostStatus = KostStatus.fromString(_statusVerifikasi);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Onboarding & Pengaturan Kos',
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
                    // BANNER STATUS VERIFIKASI PROPERTI
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: kostStatus == KostStatus.active
                            ? const Color(0xFFDCFCE7)
                            : (kostStatus == KostStatus.rejected
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kostStatus == KostStatus.active
                              ? const Color(0xFF86EFAC)
                              : (kostStatus == KostStatus.rejected
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFFFCD34D)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            kostStatus == KostStatus.active
                                ? Icons.verified_rounded
                                : (kostStatus == KostStatus.rejected
                                    ? Icons.cancel_outlined
                                    : Icons.hourglass_top_rounded),
                            color: kostStatus == KostStatus.active
                                ? const Color(0xFF166534)
                                : (kostStatus == KostStatus.rejected
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF92400E)),
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status Properti: ${kostStatus.label}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: kostStatus == KostStatus.active
                                        ? const Color(0xFF166534)
                                        : (kostStatus == KostStatus.rejected
                                            ? const Color(0xFF991B1B)
                                            : const Color(0xFF92400E)),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  kostStatus == KostStatus.active
                                      ? 'Properti kos Anda telah divalidasi oleh Super Admin dan aktif beroperasi.'
                                      : (kostStatus == KostStatus.rejected
                                          ? 'Alasan: ${_catatanVerifikasiAdmin ?? "Data KTP / tampak depan kos belum sesuai."} Silakan perbaiki data di bawah.'
                                          : 'Pengajuan kos sedang ditinjau oleh Super Admin Atur Kos.'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: kostStatus == KostStatus.active
                                        ? const Color(0xFF14532D)
                                        : (kostStatus == KostStatus.rejected
                                            ? Colors.red.shade900
                                            : Colors.amber.shade900),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _tier == 'juragan'
                                            ? '⭐ Paket Juragan (Kamar Tanpa Batas)'
                                            : 'Paket Starter (Maks $_maxRooms Kamar)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: _tier == 'juragan'
                                              ? const Color(0xFF1D4ED8)
                                              : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

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

                    // =========================================================
                    // SEKSI 1: INFORMASI UMUM PROPERTI
                    // =========================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            '1. Informasi Umum Kos',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF166534)),
                              SizedBox(width: 4),
                              Text(
                                'Terisi dari Pendaftaran',
                                style: TextStyle(fontSize: 10, color: Color(0xFF166534), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Nama kos, alamat, kontak, dan kode default otomatis terisi dari saat Anda mendaftar. Anda tinggal fokus melengkapi lokasi Maps, foto bangunan, dan foto KTP di bawah.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    _buildFieldLabel('Nama Properti Kos'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _namaKosController,
                      decoration: _buildInputDecoration(hint: 'Contoh: Kos Mawar Indah', icon: Icons.apartment_rounded),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Nama kos wajib diisi' : null,
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
                      validator: (value) => value == null || value.trim().isEmpty ? 'Alamat wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Nomor WhatsApp Admin / Pemilik'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _kontakController,
                      keyboardType: TextInputType.phone,
                      decoration: _buildInputDecoration(hint: '081234567890', icon: Icons.phone_android_rounded),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Nomor kontak wajib diisi' : null,
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Kode Undangan Kos (Wajib Unik Antar Pemilik)'),
                    const SizedBox(height: 4),
                    const Text(
                      'Kode default otomatis dibuat dari nama kos Anda. Anda dapat mengubahnya menjadi kode khusus (hanya huruf & angka, min. 3 karakter). Sistem akan memastikan kode ini belum dipakai oleh kos lain.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.35),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _kodeKostController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _buildInputDecoration(hint: 'Contoh: KOSMAWAR1', icon: Icons.qr_code_rounded),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Kode undangan wajib diisi';
                        final clean = value.trim().toUpperCase();
                        if (clean.length < 3) return 'Kode undangan minimal 3 karakter';
                        if (!RegExp(r'^[A-Z0-9]+$').hasMatch(clean)) {
                          return 'Kode hanya boleh berupa huruf dan angka tanpa spasi';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 28),

                    // =========================================================
                    // SEKSI 2: LOKASI PROPERTI KOS (PRD v2.0.0 Modul 2)
                    // =========================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            '2. Lokasi Kos (Google Maps)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: const Text('Google Maps',
                              style: TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Cukup cantumkan tautan / link Google Maps lokasi kos Anda agar penghuni dan Super Admin dapat langsung memverifikasi lokasi.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    // Tombol Ambil Lokasi GPS Otomatis (1-Klik)
                    ElevatedButton.icon(
                      onPressed: _isDetectingGps ? null : _detectCurrentGpsLocation,
                      icon: _isDetectingGps
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.my_location_rounded, size: 20),
                      label: Text(
                        _isDetectingGps ? 'Mendeteksi Titik GPS...' : '📍 Ambil Lokasi Saya Sekarang (GPS Otomatis)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'ATAU TEMPELKAN TAUTAN GOOGLE MAPS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _buildFieldLabel('Tautan / Link Google Maps Kos'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _googleMapsUrlController,
                            decoration: _buildInputDecoration(
                              hint: 'https://maps.app.goo.gl/... atau https://maps.google.com/?q=...',
                              icon: Icons.map_rounded,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _openGoogleMapsPreview,
                          icon: const Icon(Icons.open_in_new_rounded),
                          tooltip: 'Buka di Google Maps',
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '💡 Tips: Buka Google Maps, cari lokasi kos Anda, klik "Bagikan" lalu tempel link-nya di sini.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 28),

                    // =========================================================
                    // SEKSI 3: DOKUMEN VERIFIKASI FISIK (PRD v2.0.0 Modul 2)
                    // =========================================================
                    const Text(
                      '3. Dokumen Keabsahan Fisik Kos',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Unggah foto tampak depan bangunan kos dan KTP asli pemilik langsung dari kamera atau galeri untuk verifikasi Super Admin.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    // Card 1: Foto Fisik Bangunan Tampak Depan
                    _buildImageUploadCard(
                      title: 'Foto Tampak Depan / Plang Nama Kos',
                      subtitle: 'Foto fisik depan kos untuk memastikan keberadaan bangunan',
                      icon: Icons.apartment_rounded,
                      currentUrl: _fotoBangunanUrlController.text.trim(),
                      localBytes: _fotoBangunanBytes,
                      isUploading: _isUploadingBangunan,
                      onPickCamera: () => _pickImage(source: ImageSource.camera, isBangunan: true),
                      onPickGallery: () => _pickImage(source: ImageSource.gallery, isBangunan: true),
                      onRemove: () => _removeImage(isBangunan: true),
                      onPreview: () => _showImagePreview(
                        'Foto Tampak Depan Kos',
                        _fotoBangunanUrlController.text.trim(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Card 2: Foto Dokumen KTP Pemilik Kos
                    _buildImageUploadCard(
                      title: 'Dokumen KTP Asli Pemilik Kos',
                      subtitle: 'Digunakan Super Admin untuk verifikasi keabsahan identitas pengelola',
                      icon: Icons.badge_rounded,
                      currentUrl: _dokumenKtpUrlController.text.trim(),
                      localBytes: _dokumenKtpBytes,
                      isUploading: _isUploadingKtp,
                      onPickCamera: () => _pickImage(source: ImageSource.camera, isBangunan: false),
                      onPickGallery: () => _pickImage(source: ImageSource.gallery, isBangunan: false),
                      onRemove: () => _removeImage(isBangunan: false),
                      onPreview: () => _showImagePreview(
                        'Dokumen KTP Pemilik',
                        _dokumenKtpUrlController.text.trim(),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // =========================================================
                    // SEKSI 4: REKENING PEMBAYARAN SEWA
                    // =========================================================
                    const Text(
                      '4. Rekening Pembayaran Sewa',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Informasi ini otomatis muncul pada invoice tagihan anak kos saat melakukan transfer pembayaran.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                    ),
                    const SizedBox(height: 14),

                    _buildFieldLabel('Nama Bank / Dompet Digital'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _bankController,
                      decoration: _buildInputDecoration(
                        hint: 'BCA, Mandiri, BRI, BNI, dll',
                        icon: Icons.account_balance_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildFieldLabel('Nomor Rekening Bank'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _rekeningController,
                      keyboardType: TextInputType.number,
                      decoration: _buildInputDecoration(hint: '1234567890', icon: Icons.credit_card_rounded),
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

                    // TOMBOL SIMPAN SEMUA PERUBAHAN
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  kostStatus == KostStatus.active
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.send_rounded,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  kostStatus == KostStatus.active
                                      ? 'Simpan Perubahan Profil Kos'
                                      : 'Kirim Pengajuan Verifikasi ke Super Admin',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
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
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF334155)),
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
