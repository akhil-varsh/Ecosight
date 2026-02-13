/// EcoSight — Profile Screen
/// User stats, device info, battery, and settings.
library;

import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
            const SizedBox(height: 28),
            _buildUserCard(),
            const SizedBox(height: 20),
            _buildWeeklyStepsChart(),
            const SizedBox(height: 20),
            _buildDeviceInfo(),
            const SizedBox(height: 20),
            _buildUsageSummary(),
            const SizedBox(height: 20),
            _buildSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Text(
      'Profile',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A1D2E),
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9D4EDD)],
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
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Akhil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'EcoSight User • Since Jan 2026',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'PRO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyStepsChart() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final steps = [3200.0, 5400.0, 4100.0, 6800.0, 4832.0, 2100.0, 0.0];
    final maxSteps = 8000.0;

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
          const Row(
            children: [
              Text(
                'Weekly Steps',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1D2E),
                ),
              ),
              Spacer(),
              Text(
                '26,432 total',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6C63FF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final ratio = steps[i] / maxSteps;
                final isToday = (i == 4); // Friday
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          steps[i] > 0 ? '${(steps[i] / 1000).toStringAsFixed(1)}k' : '-',
                          style: TextStyle(
                            fontSize: 10,
                            color: isToday
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFF8E95A9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: ratio > 0 ? ratio : 0.02,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? const Color(0xFF6C63FF)
                                      : const Color(0xFF6C63FF).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          days[i],
                          style: TextStyle(
                            fontSize: 11,
                            color: isToday
                                ? const Color(0xFF6C63FF)
                                : const Color(0xFF8E95A9),
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceInfo() {
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
            'Device Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1D2E),
            ),
          ),
          const SizedBox(height: 16),
          // Battery with circular progress
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: 0.78,
                      strokeWidth: 5,
                      backgroundColor: const Color(0xFFF0F2F5),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF00D9A6)),
                    ),
                    const Text(
                      '78%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00D9A6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Battery',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1D2E),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Estimated 4h 20m remaining',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8E95A9),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.battery_charging_full_rounded,
                color: Color(0xFF00D9A6),
                size: 28,
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF0F2F5)),
          _buildDeviceRow(Icons.wifi_rounded, 'Connection', 'USB (adb)', const Color(0xFF6C63FF)),
          const SizedBox(height: 12),
          _buildDeviceRow(Icons.memory_rounded, 'Server', 'Running • 3.2 FPS', const Color(0xFF00D9A6)),
          const SizedBox(height: 12),
          _buildDeviceRow(Icons.model_training_rounded, 'AI Model', 'YOLOv8n + Florence-2', const Color(0xFFFFB547)),
        ],
      ),
    );
  }

  Widget _buildDeviceRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF8E95A9),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1D2E),
          ),
        ),
      ],
    );
  }

  Widget _buildUsageSummary() {
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
            'Usage Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1D2E),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildUsageStat('Phase 1\nScans', '847', const Color(0xFFFF6B6B)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUsageStat('Phase 2\nScans', '23', const Color(0xFF6C63FF)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildUsageStat('Objects\nAvoided', '156', const Color(0xFF00D9A6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
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

  Widget _buildSettings() {
    return Container(
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
        children: [
          _buildSettingsTile(Icons.volume_up_rounded, 'Speech Speed', 'Normal'),
          const Divider(height: 1, indent: 56, color: Color(0xFFF0F2F5)),
          _buildSettingsTile(Icons.vibration_rounded, 'Haptic Feedback', 'On'),
          const Divider(height: 1, indent: 56, color: Color(0xFFF0F2F5)),
          _buildSettingsTile(Icons.dark_mode_rounded, 'Theme', 'Light'),
          const Divider(height: 1, indent: 56, color: Color(0xFFF0F2F5)),
          _buildSettingsTile(Icons.info_outline_rounded, 'About', 'v1.0.0'),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6C63FF), size: 22),
          const SizedBox(width: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1D2E),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8E95A9),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Color(0xFFB0B8C9), size: 20),
        ],
      ),
    );
  }
}
