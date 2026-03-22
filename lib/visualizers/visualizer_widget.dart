import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import 'visualizer_painters.dart';

class VisualizerWidget extends StatefulWidget {
  final double height;
  const VisualizerWidget({super.key, this.height = 160});

  @override
  State<VisualizerWidget> createState() => _VisualizerWidgetState();
}

class _VisualizerWidgetState extends State<VisualizerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _rotation = 0;
  final Random _random = Random();
  List<double> _smoothed = List.filled(32, 0.0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..addListener(() {
        final service = context.read<PlayerService>();
        if (service.isPlaying) {
          setState(() {
            // Smooth the visualizer data
            final raw = service.visualizerData;
            for (int i = 0; i < _smoothed.length; i++) {
              final target = i < raw.length ? raw[i] : 0.0;
              _smoothed[i] = _smoothed[i] * 0.6 + target * 0.4;
            }
            _rotation += 0.005;
          });
        } else {
          setState(() {
            // Decay when paused
            for (int i = 0; i < _smoothed.length; i++) {
              _smoothed[i] *= 0.92;
            }
          });
        }
      })
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, service, _) {
        return Column(
          children: [
            // Mode switcher
            _buildModeSwitcher(service),
            const SizedBox(height: 12),
            // Visualizer canvas
            SizedBox(
              height: widget.height,
              width: double.infinity,
              child: _buildVisualizer(service),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModeSwitcher(PlayerService service) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ModeBtn(
          icon: Icons.equalizer_rounded,
          label: 'BARS',
          selected: service.visualizerMode == VisualizerMode.bars,
          onTap: () => service.setVisualizerMode(VisualizerMode.bars),
        ),
        const SizedBox(width: 8),
        _ModeBtn(
          icon: Icons.graphic_eq_rounded,
          label: 'WAVE',
          selected: service.visualizerMode == VisualizerMode.waveform,
          onTap: () => service.setVisualizerMode(VisualizerMode.waveform),
        ),
        const SizedBox(width: 8),
        _ModeBtn(
          icon: Icons.radio_button_checked_rounded,
          label: 'RADIAL',
          selected: service.visualizerMode == VisualizerMode.radial,
          onTap: () => service.setVisualizerMode(VisualizerMode.radial),
        ),
      ],
    );
  }

  Widget _buildVisualizer(PlayerService service) {
    switch (service.visualizerMode) {
      case VisualizerMode.bars:
        return CustomPaint(
          painter: BarVisualizerPainter(
            data: _smoothed,
            color: AppTheme.accentGreen,
            mirror: false,
          ),
        );

      case VisualizerMode.waveform:
        return CustomPaint(
          painter: WaveformVisualizerPainter(
            data: _smoothed,
            color: AppTheme.accentGreen,
          ),
        );

      case VisualizerMode.radial:
        return CustomPaint(
          painter: RadialVisualizerPainter(
            data: _smoothed,
            color: AppTheme.accentGreen,
            rotation: _rotation,
          ),
        );
    }
  }
}

class _ModeBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.accentGreen.withOpacity(0.12)
              : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected ? AppTheme.accentGreen : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 12,
                color: selected ? AppTheme.accentGreen : AppTheme.textMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppTheme.accentGreen : AppTheme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
