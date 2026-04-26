import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import 'results_screen.dart';


class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanRecord> _scans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  Future<void> _loadScans() async {
    final scans = await DatabaseHelper.instance.getAllScans();
    setState(() { _scans = scans; _loading = false; });
  }

  Color _sevColor(String s) {
    switch (s.toLowerCase()) {
      case 'none': return const Color(0xFF27AE60);
      case 'moderate': return const Color(0xFFE67E22);
      case 'high': return const Color(0xFFE74C3C);
      case 'critical': return const Color(0xFF922B21);
      default: return const Color(0xFF666666);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
            child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.history, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Scan History', style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 22, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${_scans.length} scans', style: GoogleFonts.poppins(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)))
                  : _scans.isEmpty
                      ? Center(child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.history, color: Color(0xFFE2E8F0), size: 64),
                            const SizedBox(height: 16),
                            Text('No scans yet', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 18)),
                            const SizedBox(height: 6),
                            Text('Your scan history will appear here', style: GoogleFonts.poppins(color: const Color(0xFFCBD5E1), fontSize: 13)),
                          ],
                        ))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _scans.length,
                          itemBuilder: (context, index) => _buildScanCard(_scans[index]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanCard(ScanRecord scan) {
    final dateStr = DateFormat('MMM d, yyyy · h:mm a').format(scan.scanDate);
    final imageFile = File(scan.imagePath);
    final imageExists = imageFile.existsSync();

    return GestureDetector(
      onTap: () {
        // Rebuild the full result data from the stored record
        final resultData = {
          'disease_label': scan.diseaseLabel,
          'confidence': scan.confidence,
          'health_score': scan.healthScore,
          'health_status': scan.healthStatus,
          'weather_stress': scan.weatherStress,
          'ndvi_used': scan.ndvi,
          'temperature': scan.temperature,
          'humidity': scan.humidity,
          'top5': jsonDecode(scan.top5Json),
          'treatment': scan.treatment,
          'severity': scan.severity,
          'caf': jsonDecode(scan.cafJson),
          'is_healthy': scan.diseaseLabel.toLowerCase().contains('healthy'),
          'demo_mode': false,
          'bg_removal_used': !scan.offline,
          'bg_method': scan.offline ? 'none (offline)' : 'built-in',
          'pd': scan.severity == 'none' ? (1 - scan.confidence / 100) : scan.confidence / 100,
          'ws': scan.weatherStress,
        };
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ResultsScreen(resultData: resultData, imagePath: scan.imagePath),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60, height: 60,
                color: const Color(0xFFF1F5F9),
                child: imageExists
                    ? Image.file(imageFile, fit: BoxFit.cover)
                    : const Icon(LucideIcons.image, color: Color(0xFF94A3B8), size: 24),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(scan.diseaseLabel, style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _sevColor(scan.severity).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${scan.confidence.toStringAsFixed(1)}%', style: GoogleFonts.poppins(color: _sevColor(scan.severity), fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('H: ${scan.healthScore.toStringAsFixed(0)}%', style: GoogleFonts.poppins(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                    if (scan.offline) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Offline', style: GoogleFonts.poppins(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(dateStr, style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 10)),
                ],
              ),
            ),
            // Delete
            GestureDetector(
              onTap: () async {
                await DatabaseHelper.instance.deleteScan(scan.id!);
                _loadScans();
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                child: const Icon(LucideIcons.trash2, color: const Color(0xFFCBD5E1), size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
