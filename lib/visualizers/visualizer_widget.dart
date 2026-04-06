import 'package:flutter/scheduler.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  late final Ticker _ticker;
  // FIX: made _smoothed final (it's never reassigned, only mutated in-place)
  final List<double> _smoothed = List.filled(32, 0.0);
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final service = context.read<PlayerService>();
    final isPlaying = service.isPlaying;

    Float32List raw;
    if (service.visualizerMode == VisualizerMode.waveform) {
      raw = service.waveData;
    } else {
      raw = service.fftData;
    }

    final binSize = raw.length ~/ 32;
    final downsampled = List.generate(32, (i) {
      double sum = 0;
      for (int j = i * binSize; j < (i + 1) * binSize && j < raw.length; j++) {
        sum += raw[j].abs();
      }
      return (sum / binSize).clamp(0.0, 1.0);
    });

    setState(() {
      _rotation += isPlaying ? 0.008 : 0.001;
      for (int i = 0; i < _smoothed.length; i++) {
        final target = downsampled[i];
        if (isPlaying) {
          final diff = target - _smoothed[i];
          _smoothed[i] += diff * (diff > 0 ? 0.6 : 0.12);
        } else {
          _smoothed[i] *= 0.85;
        }
        _smoothed[i] = _smoothed[i].clamp(0.0, 1.0);
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerService>(
      builder: (context, service, _) {
        return Column(
          children: [
            SizedBox(
              height: widget.height,
              width: double.infinity,
              child: _buildVisualizer(service),
            ),
            const SizedBox(height: 10),
            _buildModeSwitcher(service),
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
              ? AppTheme.accentGreen.withValues(alpha: 0.12)
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
