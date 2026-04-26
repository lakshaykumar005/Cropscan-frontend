import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../services/offline_inference.dart';
import '../services/database_helper.dart';
import 'results_screen.dart';
import 'dart:ui';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _isLoading = false;
  bool _isFetchingWeather = false;
  bool _useOffline = false;

  double _temperature = 28.0;
  double _humidity = 65.0;
  double _ndvi = 0.45;

  double? _latitude;
  double? _longitude;
  String? _ndviSource;
  String? _locationError;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Auto-fetch location on startup
    _fetchLocationAndWeather();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocationAndWeather() async {
    setState(() {
      _isFetchingWeather = true;
      _locationError = null;
    });

    try {
      // 1. Check + request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError = 'Location permission denied. Using defaults.';
          _isFetchingWeather = false;
        });
        return;
      }

      // 2. Get GPS coordinates
      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });

      // 3. Call backend /weather with lat/lon → real temp, humidity, NDVI
      final data = await ApiService.fetchWeather(
        latitude: pos.latitude,
        longitude: pos.longitude,
      );

      if (data != null && !data.containsKey('error')) {
        setState(() {
          _temperature = (data['temperature'] as num).toDouble();
          _humidity    = (data['humidity'] as num).toDouble();
          _ndvi        = (data['ndvi'] as num).toDouble();
          _ndviSource  = data['ndvi_source'] ?? 'satellite';
        });
      } else {
        setState(() {
          _locationError = 'Weather fetch failed. Using defaults.';
        });
      }
    } catch (e) {
      setState(() {
        _locationError = 'Location unavailable: ${e.toString().split(':').first}';
      });
    } finally {
      setState(() => _isFetchingWeather = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    // No imageQuality / maxWidth / maxHeight — those force image_picker to
    // re-encode and pre-resize with the platform's own (non-BILINEAR) scaler,
    // which produces pixels different from the standalone Python pipeline the
    // model was trained on. Hand the original image to PIL/dart-image so the
    // single 224×224 BILINEAR resize matches the training distribution.
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() => _imageFile = pickedFile);
    }
  }

  Future<void> _analyzeCrop() async {
    if (_imageFile == null) return;
    setState(() => _isLoading = true);

    Map<String, dynamic>? result;

    if (_useOffline && OfflineInferenceService.isReady) {
      // OFFLINE: Run ONNX model directly on phone
      result = await OfflineInferenceService.predict(
        imageFile: _imageFile!,
        temperature: _temperature,
        humidity: _humidity,
        ndvi: _ndvi,
      );
    } else {
      // ONLINE: Send to Flask backend
      result = await ApiService.predict(
        imageFile: _imageFile!,
        temperature: _temperature,
        humidity: _humidity,
        ndvi: _ndvi,
      );
    }

    setState(() => _isLoading = false);

    if (result != null) {
      // Save to local scan history
      try {
        final record = ScanRecord.fromApiResponse(
          result, _imageFile!.path,
          lat: _latitude, lon: _longitude,
          isOffline: _useOffline,
        );
        await DatabaseHelper.instance.insertScan(record);
      } catch (_) {}

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            resultData: result!,
            imagePath: _imageFile!.path,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_useOffline
              ? 'Offline model failed. Try switching to Online mode.'
              : 'Failed to analyze. Check server connection or try Offline mode.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ─────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Color(0xFF10B981).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(LucideIcons.scanLine,
                            color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CropScan',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            'Plant Disease Detection',
                            style: GoogleFonts.poppins(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Image Picker ────────────────────────────────────
                  _buildImageSelector(),

                  const SizedBox(height: 16),

                  // ── Offline / Online Toggle ─────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _useOffline ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _useOffline ? LucideIcons.wifiOff : LucideIcons.wifi,
                          color: _useOffline ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _useOffline ? 'Offline Mode (On-Device AI)' : 'Online Mode (Server)',
                              style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _useOffline
                                  ? 'ONNX model runs on your phone • No internet needed'
                                  : 'Sends image to Flask backend • BG removal enabled',
                              style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 10),
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
                  if (!OfflineInferenceService.isReady)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text('⏳ Offline model loading...', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 10)),
                    ),

                  const SizedBox(height: 16),

                  // ── Environmental Data Card ─────────────────────────
                  _buildEnvCard(),

                  const SizedBox(height: 28),

                  // ── Analyze Button ──────────────────────────────────
                  ScaleTransition(
                    scale: _imageFile != null ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _imageFile == null ? null : _analyzeCrop,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          disabledBackgroundColor:
                              Colors.white.withValues(alpha: 0.05),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.microscope, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              _imageFile == null
                                  ? 'Upload a Leaf Image First'
                                  : 'Analyze Crop Health',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
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
          ),
          // Full-screen loading overlay
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF10B981)),
                    const SizedBox(height: 20),
                    Text(
                      'Analyzing crop with AI...',
                      style: GoogleFonts.poppins(
                          color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageSelector() {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF94A3B8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                _sheetTile(LucideIcons.camera, 'Take a Photo',
                    () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
                _sheetTile(LucideIcons.image, 'Choose from Gallery',
                    () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
              ],
            ),
          ),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 210,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _imageFile != null
                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: _imageFile != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.refreshCw,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 6),
                          Text('Change',
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.scanLine,
                        color: Color(0xFF10B981), size: 34),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Tap to upload leaf image',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF475569),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Camera or Gallery',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8), fontSize: 13),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFF10B981).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Color(0xFF10B981), size: 20),
      ),
      title: Text(title,
          style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 15)),
      onTap: onTap,
    );
  }

  Widget _buildEnvCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Text(
                'Environmental Data',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF0F172A),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _isFetchingWeather ? null : _fetchLocationAndWeather,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isFetchingWeather
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isFetchingWeather
                          ? Colors.white12
                          : const Color(0xFF10B981).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _isFetchingWeather
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF10B981)),
                            )
                          : const Icon(LucideIcons.mapPin,
                              size: 12, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Text(
                        _isFetchingWeather ? 'Locating...' : 'Auto-detect',
                        style: GoogleFonts.poppins(
                          color: _isFetchingWeather
                              ? Colors.white38
                              : const Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Location info
          if (_latitude != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.navigation,
                    size: 12, color: const Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  '${_latitude!.toStringAsFixed(4)}°N, ${_longitude!.toStringAsFixed(4)}°E',
                  style: GoogleFonts.poppins(
                      color: const Color(0xFF94A3B8), fontSize: 11),
                ),
                if (_ndviSource != null && _ndviSource != 'fallback') ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'NDVI: Satellite ✓',
                      style: GoogleFonts.poppins(
                          color: Color(0xFF10B981), fontSize: 10),
                    ),
                  )
                ],
              ],
            ),
          ],
          if (_locationError != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.alertCircle,
                    size: 12, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _locationError!,
                    style: GoogleFonts.poppins(
                        color: Colors.orange, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Sliders
          _buildDarkSlider(
            label: 'Temperature',
            value: _temperature,
            min: 0,
            max: 50,
            unit: '°C',
            onChanged: (v) => setState(() => _temperature = v),
            icon: LucideIcons.thermometer,
            color: Color(0xFF3B82F6),
          ),
          const SizedBox(height: 18),
          _buildDarkSlider(
            label: 'Humidity',
            value: _humidity,
            min: 0,
            max: 100,
            unit: '%',
            onChanged: (v) => setState(() => _humidity = v),
            icon: LucideIcons.droplets,
            color: Color(0xFF3B82F6),
          ),
          const SizedBox(height: 18),
          _buildDarkSlider(
            label: 'NDVI Index',
            value: _ndvi,
            min: -1.0,
            max: 1.0,
            unit: '',
            onChanged: (v) => setState(() => _ndvi = double.parse(v.toStringAsFixed(2))),
            icon: LucideIcons.leaf,
            color: Color(0xFF10B981),
          ),

          // NDVI explanation
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.satellite,
                    size: 14, color: const Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'NDVI is auto-fetched from NASA MODIS satellite. Temperature & humidity via Open-Meteo.',
                    style: GoogleFonts.poppins(
                        color: const Color(0xFF94A3B8), fontSize: 11, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Function(double) onChanged,
    required IconData icon,
    required Color color,
  }) {
    final pct = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.poppins(
                    color: const Color(0xFF475569),
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(
              '${value.toStringAsFixed(1)}$unit',
              style: GoogleFonts.poppins(
                color: const Color(0xFF0F172A),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.12),
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.15),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        // Progress indicator strip
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: color.withValues(alpha: 0.08),
            color: color.withValues(alpha: 0.4),
            minHeight: 3,
          ),
        ),
      ],
    );
  }
}
