import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:clarity/core/release/clarity_build_provenance.dart';
import 'package:clarity/rex/voice/application/voice_session_trace.dart';
import 'package:clarity/rex/voice/data/voice_vad_telemetry.dart';
import 'package:clarity/theme/clarity_colors.dart';
import 'package:clarity/widgets/clarity_card.dart';

/// Owner-only build provenance + voice session trace export.
class OwnerDebugPanel extends StatefulWidget {
  const OwnerDebugPanel({super.key});

  @override
  State<OwnerDebugPanel> createState() => _OwnerDebugPanelState();
}

class _OwnerDebugPanelState extends State<OwnerDebugPanel> {
  ClarityBuildProvenance? _provenance;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final provenance = await ClarityBuildProvenance.load();
      if (!mounted) {
        return;
      }
      setState(() {
        _provenance = provenance;
        _error = null;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _copyTrace() async {
    final provenance = _provenance ?? await ClarityBuildProvenance.load();
    final text = VoiceSessionTrace.instance.exportText(provenance: provenance);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied voice trace (${VoiceSessionTrace.instance.entries.length} events)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.clarityColors;
    final provenance = _provenance;

    return ClarityCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: colors.surface.withValues(alpha: 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Build provenance',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Text(_error!, style: theme.textTheme.bodySmall)
          else if (provenance == null)
            Text('Loading…', style: theme.textTheme.bodySmall)
          else ...[
            _row(theme, colors, 'Git SHA', provenance.gitSha),
            _row(theme, colors, 'Branch', provenance.gitBranch),
            _row(theme, colors, 'App version', provenance.appVersion),
            _row(theme, colors, 'Build number', provenance.buildNumber),
            _row(theme, colors, 'Build timestamp', provenance.buildTimestamp),
          ],
          const SizedBox(height: 14),
          Text(
            'VAD telemetry (no audio)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            VoiceVadTelemetry.instance.summaryLine(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Voice session trace',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ring buffer of authority events (no audio, credentials, or full chat). '
            'Entries: ${VoiceSessionTrace.instance.entries.length}',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: _copyTrace,
                child: const Text('Copy voice trace'),
              ),
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: VoiceVadTelemetry.instance.summaryLine()),
                  );
                  if (!mounted) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied VAD telemetry')),
                  );
                },
                child: const Text('Copy VAD telemetry'),
              ),
              TextButton(
                onPressed: () {
                  VoiceSessionTrace.instance.clear();
                  setState(() {});
                },
                child: const Text('Clear trace'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    ThemeData theme,
    ClarityColorTokens colors,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
