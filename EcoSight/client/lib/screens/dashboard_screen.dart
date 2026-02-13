/// EcoSight — Dashboard Screen
/// Main overview with stats, detected objects, and activity summary.
library;

import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
            _buildStatsRow(),
            const SizedBox(height: 24),
            _buildPathTrackingCard(),
            const SizedBox(height: 20),
            _buildDetectedObjectsList(),
            const SizedBox(height: 20),
            _buildActivityTimeline(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.visibility, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good Morning 👋',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF8E95A9),
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'EcoSight Dashboard',
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF6C63FF),
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.directions_walk_rounded,
            label: 'Steps',
            value: '4,832',
            color: const Color(0xFF00D9A6),
            bgColor: const Color(0xFFE6FFF7),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.battery_charging_full_rounded,
            label: 'Battery',
            value: '78%',
            color: const Color(0xFFFFB547),
            bgColor: const Color(0xFFFFF5E1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.warning_amber_rounded,
            label: 'Alerts',
            value: '12',
            color: const Color(0xFFFF6B6B),
            bgColor: const Color(0xFFFFEBEB),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8E95A9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPathTrackingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: Color(0xFF00FF94)),
                    SizedBox(width: 6),
                    Text(
                      'LIVE TRACKING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.map_rounded, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Current Route',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Campus Main Road → Library',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          // Mini path visualization
          Row(
            children: [
              _buildPathDot(true),
              Expanded(child: _buildPathLine()),
              _buildPathDot(true),
              Expanded(child: _buildPathLine()),
              _buildPathDot(true),
              Expanded(child: _buildPathDash()),
              _buildPathDot(false),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Start', style: TextStyle(color: Colors.white60, fontSize: 11)),
              const Text('Gate 2', style: TextStyle(color: Colors.white60, fontSize: 11)),
              const Text('Café', style: TextStyle(color: Colors.white60, fontSize: 11)),
              Text('Library', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.straighten_rounded, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              const Text('320m walked', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 20),
              const Icon(Icons.timer_outlined, color: Colors.white70, size: 16),
              const SizedBox(width: 6),
              const Text('8 min', style: TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPathDot(bool completed) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed ? Colors.white : Colors.white.withValues(alpha: 0.3),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildPathLine() {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildPathDash() {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildDetectedObjectsList() {
    final detections = [
      {'object': 'Person', 'dir': 'Center', 'dist': '1.2m', 'time': '2s ago', 'icon': Icons.person, 'color': const Color(0xFFFF6B6B)},
      {'object': 'Chair', 'dir': 'Left', 'dist': '2.5m', 'time': '5s ago', 'icon': Icons.chair, 'color': const Color(0xFFFFB547)},
      {'object': 'Bicycle', 'dir': 'Right', 'dist': '3.8m', 'time': '12s ago', 'icon': Icons.pedal_bike, 'color': const Color(0xFF00D9A6)},
      {'object': 'Bottle', 'dir': 'Center', 'dist': '0.8m', 'time': '18s ago', 'icon': Icons.local_drink, 'color': const Color(0xFF6C63FF)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Detected Objects',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1D2E),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '4 in path',
                style: TextStyle(
                  color: Color(0xFF6C63FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...detections.map((d) => _buildDetectionTile(d)),
      ],
    );
  }

  Widget _buildDetectionTile(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (d['color'] as Color).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(d['icon'] as IconData, color: d['color'] as Color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d['object'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1D2E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${d['dir']} • ${d['dist']}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E95A9),
                  ),
                ),
              ],
            ),
          ),
          Text(
            d['time'] as String,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFFB0B8C9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1D2E),
          ),
        ),
        const SizedBox(height: 14),
        _buildTimelineItem(
          '09:15 AM',
          'Started navigation',
          'Campus entrance',
          const Color(0xFF00D9A6),
          Icons.play_circle_filled_rounded,
        ),
        _buildTimelineItem(
          '09:22 AM',
          'Scene scan requested',
          'Identified: outdoor walkway with trees',
          const Color(0xFF6C63FF),
          Icons.image_search_rounded,
        ),
        _buildTimelineItem(
          '09:28 AM',
          '3 obstacles avoided',
          'Person, chair, bicycle detected',
          const Color(0xFFFFB547),
          Icons.shield_rounded,
        ),
        _buildTimelineItem(
          '09:35 AM',
          'Scene scan requested',
          'Identified: library entrance with stairs',
          const Color(0xFF6C63FF),
          Icons.image_search_rounded,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineItem(
    String time,
    String title,
    String subtitle,
    Color color,
    IconData icon, {
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF8E95A9),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: const Color(0xFFE8ECF2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1D2E),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E95A9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
