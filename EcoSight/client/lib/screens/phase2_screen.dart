/// EcoSight — Phase 2 Screen (Context Layer)
/// Environmental understanding and scene description history.
library;

import 'package:flutter/material.dart';

class Phase2Screen extends StatelessWidget {
  const Phase2Screen({super.key});

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
            _buildScanButton(),
            const SizedBox(height: 24),
            _buildLastScanCard(),
            const SizedBox(height: 20),
            _buildScanHistory(),
            const SizedBox(height: 20),
            _buildEnvironmentStats(),
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
            color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.explore_rounded, color: Color(0xFF6C63FF), size: 24),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PHASE 2',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF6C63FF),
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Environment AI',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScanButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.camera_alt_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Scan Environment',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Double-tap to describe your surroundings',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastScanCard() {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9A6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Latest Scan',
                  style: TextStyle(
                    color: Color(0xFF00D9A6),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              const Text(
                '2 min ago',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8E95A9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'An outdoor walkway with a tall tree on the left side. '
            'The path is made of concrete pavement with mild sunlight. '
            'There are two people walking ahead at approximately 10 meters. '
            'A bicycle is parked on the right side near a metal fence.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF4A5068),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag('Outdoor'),
              _buildTag('Walkway'),
              _buildTag('Sunny'),
              _buildTag('2 People'),
              _buildTag('Bicycle'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF6C63FF),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildScanHistory() {
    final scans = [
      {
        'time': '09:35 AM',
        'location': 'Library Entrance',
        'desc': 'A building entrance with glass doors and steps. Two benches on either side.',
        'tags': ['Indoor', 'Steps', 'Building'],
      },
      {
        'time': '09:22 AM',
        'location': 'Campus Walkway',
        'desc': 'An outdoor road lined with trees. Mild sunlight, clear path ahead.',
        'tags': ['Outdoor', 'Trees', 'Clear'],
      },
      {
        'time': '09:10 AM',
        'location': 'Parking Area',
        'desc': 'A parking lot with several cars. Speed bump visible at 5 meters.',
        'tags': ['Parking', 'Cars', 'Speed bump'],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Scan History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D2E),
          ),
        ),
        const SizedBox(height: 14),
        ...scans.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.image_search_rounded,
                          color: Color(0xFF6C63FF), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        s['location'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D2E),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        s['time'] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB0B8C9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s['desc'] as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8E95A9),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: (s['tags'] as List).map((t) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            t as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8E95A9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )).toList(),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildEnvironmentStats() {
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
            'Environment Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1D2E),
            ),
          ),
          const SizedBox(height: 16),
          _buildInsightRow(Icons.wb_sunny_rounded, 'Lighting', 'Well-lit',
              const Color(0xFFFFB547)),
          const Divider(height: 20, color: Color(0xFFF0F2F5)),
          _buildInsightRow(Icons.terrain_rounded, 'Surface', 'Paved',
              const Color(0xFF00D9A6)),
          const Divider(height: 20, color: Color(0xFFF0F2F5)),
          _buildInsightRow(Icons.people_rounded, 'Crowd Level', 'Low',
              const Color(0xFF6C63FF)),
          const Divider(height: 20, color: Color(0xFFF0F2F5)),
          _buildInsightRow(Icons.volume_up_rounded, 'Noise Level', 'Moderate',
              const Color(0xFFFF6B6B)),
        ],
      ),
    );
  }

  Widget _buildInsightRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF8E95A9),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1D2E),
          ),
        ),
      ],
    );
  }
}
