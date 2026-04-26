import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';


class ResultsScreen extends StatelessWidget {
  final Map<String, dynamic> resultData;
  final String imagePath;

  const ResultsScreen({
    super.key,
    required this.resultData,
    required this.imagePath,
  });

  // ── Helpers ──────────────────────────────────────────────
  Color _sevColor(String s) {
    switch (s.toLowerCase()) {
      case 'none': return const Color(0xFF1E8449);
      case 'moderate': return const Color(0xFFD35400);
      case 'high': return const Color(0xFFC0392B);
      case 'critical': return const Color(0xFF922B21);
      default: return const Color(0xFF666666);
    }
  }
  Color _sevBg(String s) {
    switch (s.toLowerCase()) {
      case 'none': return const Color(0xFFEAF6EF);
      case 'moderate': return const Color(0xFFFEF4E8);
      case 'high': return const Color(0xFFFDECEA);
      case 'critical': return const Color(0xFFFDECEA);
      default: return const Color(0xFFF4F4F4);
    }
  }
  String _sevLabel(String s) {
    switch (s.toLowerCase()) {
      case 'none': return 'Healthy';
      case 'moderate': return 'Moderate';
      case 'high': return 'High Risk';
      case 'critical': return 'CRITICAL';
      default: return 'Unknown';
    }
  }
  Color _healthColor(double h) {
    if (h > 60) return const Color(0xFF27AE60);
    if (h >= 30) return const Color(0xFFE67E22);
    return const Color(0xFFE74C3C);
  }
  Color _healthBg(double h) {
    if (h > 60) return const Color(0xFFEAF6EF);
    if (h >= 30) return const Color(0xFFFEF4E8);
    return const Color(0xFFFDECEA);
  }

  @override
  Widget build(BuildContext context) {
    // ── Parse ALL variables from API response ──────────────
    final String label = resultData['disease_label'] ?? 'Unknown';
    final double confidence = (resultData['confidence'] as num).toDouble();
    final double healthScore = (resultData['health_score'] as num).toDouble();
    final String healthStatus = resultData['health_status'] ?? '';
    final double weatherStress = (resultData['weather_stress'] as num).toDouble();
    final double ndviUsed = (resultData['ndvi_used'] as num).toDouble();
    final double temperature = (resultData['temperature'] as num).toDouble();
    final double humidity = (resultData['humidity'] as num).toDouble();
    final String treatment = resultData['treatment'] ?? 'Consult an expert.';
    final String severity = resultData['severity'] ?? 'unknown';
    final bool demoMode = resultData['demo_mode'] ?? false;
    final bool bgUsed = resultData['bg_removal_used'] ?? false;
    final double pd = (resultData['pd'] as num?)?.toDouble() ?? 0.0;
    final double ws = (resultData['ws'] as num?)?.toDouble() ?? 0.0;
    final List<dynamic> top5 = resultData['top5'] ?? [];
    final Map<String, dynamic> caf = resultData['caf'] ?? {};

    // CAF values
    final double cafH = caf['H_adaptive'] != null ? (caf['H_adaptive'] as num).toDouble() * 100 : healthScore;
    final double cafW1 = (caf['w1'] as num?)?.toDouble() ?? 0.45;
    final double cafW2 = (caf['w2'] as num?)?.toDouble() ?? 0.35;
    final double cafW3 = (caf['w3'] as num?)?.toDouble() ?? 0.20;
    final double rCnn = (caf['r_cnn'] as num?)?.toDouble() ?? 0;
    final double rNdvi = (caf['r_ndvi'] as num?)?.toDouble() ?? 0;
    final double rWeather = (caf['r_weather'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
            child: Column(
              children: [
                // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.arrowLeft, color: Color(0xFF0F172A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Scan Result', style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: demoMode ? const Color(0xFFE67E22) : const Color(0xFF27AE60),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(demoMode ? 'Demo' : 'Real Model ✓', style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ═══ 1. DIAGNOSIS CARD ═══
                    _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _secTitle('Diagnosis'),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: File(imagePath).existsSync()
                                  ? Image.file(File(imagePath), width: 90, height: 90, fit: BoxFit.cover)
                                  : Container(
                                      width: 90, height: 90,
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(LucideIcons.image, color: Color(0xFF94A3B8), size: 30),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(label, style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 6),
                                Wrap(spacing: 6, runSpacing: 4, children: [
                                  _tag(_sevLabel(severity), _sevColor(severity), _sevBg(severity)),
                                  _tag('CNN ${confidence.toStringAsFixed(1)}%', const Color(0xFF1A5FA6), const Color(0xFFE8F4FF)),
                                  if (bgUsed) _tag('BG Removed', const Color(0xFF7B2FA8), const Color(0xFFF0E6FF)),
                                  _tag(demoMode ? 'Demo' : 'Real Model', demoMode ? const Color(0xFFE67E22) : const Color(0xFF1E8449), demoMode ? const Color(0xFFFFF3E0) : const Color(0xFFEAF6EF)),
                                ]),
                              ],
                            )),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Confidence bar
                        Row(
                          children: [
                            Text('Model Confidence', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 11)),
                            const Spacer(),
                            Text('${confidence.toStringAsFixed(1)}%', style: GoogleFonts.poppins(color: const Color(0xFF27AE60), fontSize: 14, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: confidence / 100,
                            backgroundColor: Color(0xFFE2E8F0),
                            color: const Color(0xFF27AE60),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    )),

                    // ═══ 2. HEALTH SCORE — Eq.15 ═══
                    _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _secTitle('Crop Health Score'),
                            const Spacer(),
                            Text('Paper Eq. 15', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 10)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Big score + status
                        Center(child: Column(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _healthBg(healthScore),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(healthStatus, style: GoogleFonts.poppins(color: _healthColor(healthScore), fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 10),
                          Text(healthScore.toStringAsFixed(1), style: GoogleFonts.poppins(color: const Color(0xFF0F172A), fontSize: 48, fontWeight: FontWeight.w800)),
                          Text('/100', style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 14)),
                        ])),
                        const SizedBox(height: 16),
                        // Pills: Temp, Humidity, W.Stress, NDVI
                        Row(children: [
                          _pill('${temperature.toStringAsFixed(0)}°C', 'TEMP', const Color(0xFFE74C3C)),
                          const SizedBox(width: 8),
                          _pill('${humidity.toStringAsFixed(0)}%', 'HUMIDITY', const Color(0xFF3498DB)),
                          const SizedBox(width: 8),
                          _pill(weatherStress.toStringAsFixed(2), 'W.STRESS', const Color(0xFFE67E22)),
                          const SizedBox(width: 8),
                          _pill(ndviUsed.toStringAsFixed(2), 'NDVI', const Color(0xFF27AE60)),
                        ]),
                        const SizedBox(height: 14),
                        // Score breakdown pills
                        _secTitle('Score Breakdown (Eq. 15)'),
                        const SizedBox(height: 8),
                        Row(children: [
                          _scorePill('CNN health', '${((1 - pd) * 100).toStringAsFixed(0)}%', 'w1=0.45', const Color(0xFF3498DB)),
                          const SizedBox(width: 8),
                          _scorePill('NDVI vigour', '${(ndviUsed * 100).toStringAsFixed(0)}%', 'w2=0.35', const Color(0xFF27AE60)),
                          const SizedBox(width: 8),
                          _scorePill('Wx favour', '${((1 - weatherStress) * 100).toStringAsFixed(0)}%', 'w3=0.20', const Color(0xFFE67E22)),
                        ]),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: _healthBg(healthScore), borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('H = ${healthScore.toStringAsFixed(1)}%', style: GoogleFonts.poppins(color: _healthColor(healthScore), fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(healthStatus, style: GoogleFonts.poppins(color: _healthColor(healthScore), fontSize: 14, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ],
                    )),

                    // ═══ 3. CAF — ADAPTIVE FUSION (NOVEL) ═══
                    _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _secTitle('CAF — Adaptive Fusion (Novel)'),
                        const SizedBox(height: 6),
                        Text('CAF re-weights each modality dynamically by its real-time reliability — unlike fixed Eq.18 weights.',
                          style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 11, height: 1.5)),
                        const SizedBox(height: 14),
                        Row(children: [
                          _cafWeight('CNN', cafW1, const Color(0xFF3498DB)),
                          const SizedBox(width: 10),
                          _cafWeight('NDVI', cafW2, const Color(0xFF27AE60)),
                          const SizedBox(width: 10),
                          _cafWeight('Weather', cafW3, const Color(0xFFE67E22)),
                        ]),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: _healthBg(cafH), borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('CAF health score', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 12)),
                            Text('${cafH.toStringAsFixed(1)}% — ${cafH > 60 ? "Healthy" : (cafH >= 30 ? "Moderate Risk" : "High Risk")}',
                              style: GoogleFonts.poppins(color: _healthColor(cafH), fontSize: 14, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Text('r_cnn=${rCnn.toStringAsFixed(2)} · r_ndvi=${rNdvi.toStringAsFixed(2)} · r_wx=${rWeather.toStringAsFixed(2)}',
                          style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 10)),
                      ],
                    )),

                    // ═══ 4. ENVIRONMENTAL INPUTS USED ═══
                    _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _secTitle('Environmental Inputs Used'),
                        const SizedBox(height: 10),
                        Row(children: [
                          _envItem('Temperature', '${temperature.toStringAsFixed(0)}°C', const Color(0xFFE74C3C)),
                          const SizedBox(width: 8),
                          _envItem('Humidity', '${humidity.toStringAsFixed(0)}%', const Color(0xFF3498DB)),
                          const SizedBox(width: 8),
                          _envItem('NDVI', ndviUsed.toStringAsFixed(2), const Color(0xFF27AE60)),
                          const SizedBox(width: 8),
                          _envItem('Wx stress', ws.toStringAsFixed(2), const Color(0xFFE67E22)),
                        ]),
                      ],
                    )),

                    // ═══ 5. TOP-5 PREDICTIONS ═══
                    _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _secTitle('Top 5 Predictions'),
                        const SizedBox(height: 10),
                        ...List.generate(top5.length, (i) {
                          final item = top5[i];
                          final prob = (item['prob'] as num).toDouble();
                          final maxProb = (top5[0]['prob'] as num).toDouble();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 20, height: 20,
                                    decoration: BoxDecoration(
                                      color: i == 0 ? const Color(0xFF27AE60).withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Center(child: Text('${i + 1}', style: GoogleFonts.poppins(color: i == 0 ? const Color(0xFF27AE60) : const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w700))),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(item['label'] ?? '', style: GoogleFonts.poppins(color: const Color(0xFF334155), fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  Text('${prob.toStringAsFixed(1)}%', style: GoogleFonts.poppins(color: i == 0 ? const Color(0xFF27AE60) : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w700)),
                                ]),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: maxProb > 0 ? prob / maxProb : 0,
                                    backgroundColor: const Color(0xFFF1F5F9),
                                    color: i == 0 ? const Color(0xFF27AE60) : const Color(0xFF4A7A5C),
                                    minHeight: 6,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    )),

                    // ═══ 6. RECOMMENDED ACTION ═══
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _sevBg(severity).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _sevColor(severity).withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            _secTitle('Recommended Action'),
                            const Spacer(),
                            _tag(_sevLabel(severity), _sevColor(severity), _sevBg(severity)),
                          ]),
                          const SizedBox(height: 10),
                          Text(treatment, style: GoogleFonts.poppins(color: const Color(0xFF334155), fontSize: 13, height: 1.65)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ═══ 7. PIPELINE INFO ═══
                    _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _secTitle('Model Pipeline'),
                        const SizedBox(height: 10),
                        _pipelineItem(LucideIcons.brain, 'MobileNetV3-Large', '38-class PlantVillage · 224×224 · 2-phase fine-tune'),
                        _pipelineItem(LucideIcons.globe, 'NDVI / EVI / SAVI (Eq.10–12)', 'Vegetation indices · normalised Vn (Eq.13)'),
                        _pipelineItem(LucideIcons.cloud, 'Weather Stress (Eq.14)', 'Temp + humidity → Ws stress score'),
                        _pipelineItem(LucideIcons.beaker, 'XGBoost Fusion (Eq.15)', 'w1=0.45 · w2=0.35 · w3=0.20 (Eq.18)'),
                        _pipelineItem(LucideIcons.sparkles, 'CAF — Novel Algorithm', 'Confidence-adaptive weights per sample'),
                      ],
                    )),

                    // ═══ SCAN AGAIN ═══
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity, height: 56,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(LucideIcons.scanLine, size: 18),
                          const SizedBox(width: 8),
                          Text('Scan Another Leaf', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reusable Widgets ────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _secTitle(String t) {
    return Text(t, style: GoogleFonts.poppins(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6));
  }

  Widget _tag(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: GoogleFonts.poppins(color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _pill(String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: GoogleFonts.poppins(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 9)),
      ]),
    ));
  }

  Widget _scorePill(String label, String value, String weight, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text(value, style: GoogleFonts.poppins(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 10)),
        Text(weight, style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 9)),
      ]),
    ));
  }

  Widget _cafWeight(String label, double w, Color color) {
    return Expanded(child: Column(children: [
      Text('${(w * 100).toStringAsFixed(0)}%', style: GoogleFonts.poppins(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
      Text(label, style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 10)),
      const SizedBox(height: 4),
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(value: w, backgroundColor: Color(0xFFE2E8F0), color: color, minHeight: 4),
      ),
    ]));
  }

  Widget _envItem(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(value, style: GoogleFonts.poppins(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 9)),
      ]),
    ));
  }

  Widget _pipelineItem(IconData icon, String title, String sub) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: const Color(0xFF27AE60), size: 16),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: GoogleFonts.poppins(color: const Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600)),
          Text(sub, style: GoogleFonts.poppins(color: const Color(0xFF94A3B8), fontSize: 10, height: 1.4)),
        ])),
      ]),
    );
  }
}
