/// EcoSight — Phase 1 Screen (Reflex Layer)
/// Real-time object detection and hazard alerts display.
library;

import 'package:flutter/material.dart';

class Phase1Screen extends StatelessWidget {
  const Phase1Screen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatusCard(),
            const SizedBox(height: 20),
            _buildNearestHazardCard(),
            const SizedBox(height: 20),
            _buildRecentDetections(),
            const SizedBox(height: 20),
            _buildDetectionHeatmap(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.radar_rounded, color: Color(0xFFFF6B6B), size: 24),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PHASE 1',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFFFF6B6B),
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Reflex Layer',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF00D9A6).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF00D9A6).withValues(alpha: 0.3),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: Color(0xFF00D9A6)),
              SizedBox(width: 6),
              Text(
                'ACTIVE',
                style: TextStyle(
                  color: Color(0xFF00D9A6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildMiniStat('FPS', '3.2', const Color(0xFF6C63FF)),
          _buildDivider(),
          _buildMiniStat('Objects', '4', const Color(0xFFFFB547)),
          _buildDivider(),
          _buildMiniStat('Confidence', '87%', const Color(0xFF00D9A6)),
          _buildDivider(),
          _buildMiniStat('Alerts', '12', const Color(0xFFFF6B6B)),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8E95A9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: const Color(0xFFE8ECF2),
    );
  }

  Widget _buildNearestHazardCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B6B).withValues(alpha: 0.08),
            const Color(0xFFFF6B6B).withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B), size: 20),
              SizedBox(width: 8),
              Text(
                'Nearest Hazard',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.person, color: Color(0xFFFF6B6B), size: 36),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PERSON',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.straighten, size: 16, color: Color(0xFF8E95A9)),
                        SizedBox(width: 4),
                        Text(
                          '1.2 meters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E95A9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.arrow_upward_rounded, size: 16, color: Color(0xFF8E95A9)),
                        SizedBox(width: 4),
                        Text(
                          'Center',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E95A9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentDetections() {
    final items = [
      {'name': 'Person', 'dist': '1.2m', 'dir': 'Center', 'conf': '92%', 'color': const Color(0xFFFF6B6B)},
      {'name': 'Chair', 'dist': '2.5m', 'dir': 'Left', 'conf': '88%', 'color': const Color(0xFFFFB547)},
      {'name': 'Bicycle', 'dist': '3.8m', 'dir': 'Right', 'conf': '76%', 'color': const Color(0xFF00D9A6)},
      {'name': 'Laptop', 'dist': '1.8m', 'dir': 'Left', 'conf': '94%', 'color': const Color(0xFF6C63FF)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'All Detections',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D2E),
          ),
        ),
        const SizedBox(height: 14),
        ...items.map((item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item['color'] as Color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] as String,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1D2E),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${item['dir']} • ${item['dist']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF8E95A9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (item['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['conf'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: item['color'] as Color,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildDetectionHeatmap() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Direction Distribution',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1D2E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildDirectionBar('Left', 0.35, const Color(0xFF6C63FF)),
              const SizedBox(width: 8),
              _buildDirectionBar('Center', 0.55, const Color(0xFFFF6B6B)),
              const SizedBox(width: 8),
              _buildDirectionBar('Right', 0.25, const Color(0xFF00D9A6)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionBar(String label, double ratio, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8E95A9),
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '${(ratio * 100).toInt()}%',
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
