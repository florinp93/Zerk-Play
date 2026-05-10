import 'dart:io';

import 'package:flutter/material.dart';

import '../player/mpv_config_service.dart';
import '../player/playback_prefs.dart';

/// Opens the full mpv player settings dialog.
///
/// Every control writes to [mpv.conf] on save; playback picks up changes on next open.
/// [onSavePlaybackPrefs] is called only for the app-level prefs (display refresh rate).
Future<void> showPlayerMpvSettingsDialog({
  required BuildContext context,
  required PlaybackPrefs playbackPrefs,
  required Future<void> Function(PlaybackPrefs next) onSavePlaybackPrefs,
}) async {
  final text = await MpvConfigService.readConfigText();
  final conf = MpvConfigService.parseConf(text);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _MpvSettingsDialog(
      initialConf: conf,
      appPrefs: playbackPrefs,
      onSaveAppPrefs: onSavePlaybackPrefs,
    ),
  );
}

// ─── Dialog widget ────────────────────────────────────────────────────────────

class _MpvSettingsDialog extends StatefulWidget {
  const _MpvSettingsDialog({
    required this.initialConf,
    required this.appPrefs,
    required this.onSaveAppPrefs,
  });

  final Map<String, String> initialConf;
  final PlaybackPrefs appPrefs;
  final Future<void> Function(PlaybackPrefs) onSaveAppPrefs;

  @override
  State<_MpvSettingsDialog> createState() => _MpvSettingsDialogState();
}

class _MpvSettingsDialogState extends State<_MpvSettingsDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final Map<String, String> _conf;
  late bool _matchHz;
  late bool _matchHzFsOnly;
  bool _saving = false;

  // ── Value accessors ────────────────────────────────────────────────────────

  String _g(String key, String def) => _conf[key] ?? def;
  bool _gb(String key, bool def) => (_conf[key] ?? (def ? 'yes' : 'no')) == 'yes';
  double _gd(String key, double def) => double.tryParse(_conf[key] ?? '') ?? def;
  int _gi(String key, int def) => int.tryParse(_conf[key] ?? '') ?? def;

  void _s(String key, String val) => setState(() => _conf[key] = val);
  void _sb(String key, bool val) => _s(key, val ? 'yes' : 'no');

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _conf = Map.of(widget.initialConf);
    _matchHz = widget.appPrefs.matchDisplayRefreshRate;
    _matchHzFsOnly = widget.appPrefs.matchDisplayRefreshRateFullscreenOnly;
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  static const List<String> _videoKeyOrder = [
    'hwdec', 'gpu-api', 'vo', 'video-sync', 'interpolation', 'tscale',
    'scale', 'dscale', 'cscale', 'correct-downscaling', 'linear-downscaling',
    'sigmoid-upscaling', 'dither', 'deband', 'deband-iterations',
    'deband-threshold', 'deband-range', 'deband-grain',
    'hdr-compute-peak', 'target-colorspace-hint', 'tone-mapping',
    'hr-seek', 'hr-seek-framedrop', 'save-position-on-quit',
  ];

  static const List<String> _audioKeyOrder = [
    'audio-pitch-correction', 'audio-normalize-downmix', 'volume-max', 'audio-delay',
  ];

  static const List<String> _subtitleKeyOrder = [
    'sub-ass-override', 'sub-font-size', 'sub-scale', 'sub-margin-y', 'sub-margin-x',
    'sub-border-size', 'sub-shadow-offset', 'sub-blur', 'sub-pos', 'sub-delay',
    'sub-fix-timing',
  ];

  static const List<String> _networkKeyOrder = [
    'network-timeout', 'tls-verify', 'cache', 'cache-secs',
    'demuxer-max-bytes', 'demuxer-max-back-bytes', 'demuxer-readahead-secs',
    'cache-on-disk',
  ];

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      // Rebuild map in section order so buildConf output is predictable
      final ordered = <String, String>{};
      final knownKeys = <String>{
        ..._videoKeyOrder, ..._audioKeyOrder, ..._subtitleKeyOrder, ..._networkKeyOrder,
      };
      for (final k in [
        ..._videoKeyOrder, ..._audioKeyOrder, ..._subtitleKeyOrder, ..._networkKeyOrder,
      ]) {
        if (_conf.containsKey(k)) ordered[k] = _conf[k]!;
      }
      // Append custom keys that were in the original conf but not managed by the UI
      for (final e in _conf.entries) {
        if (!knownKeys.contains(e.key)) ordered[e.key] = e.value;
      }

      await MpvConfigService.writeConfigText(MpvConfigService.buildConf(ordered));
      await widget.onSaveAppPrefs(
        widget.appPrefs.copyWith(
          matchDisplayRefreshRate: _matchHz,
          matchDisplayRefreshRateFullscreenOnly: _matchHzFsOnly,
        ),
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  Widget _sectionHeader(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );

  Widget _infoBox(String text) => Container(
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );

  /// Toggle switch row.
  Widget _sw(String key, String label, bool def, {String? help, bool enabled = true}) {
    return SwitchListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(label),
      subtitle: help != null
          ? Text(help, style: Theme.of(context).textTheme.bodySmall)
          : null,
      value: _gb(key, def),
      onChanged: enabled ? (v) => _sb(key, v) : null,
    );
  }

  /// Dropdown row with labelled options.
  Widget _dd(
    String key,
    String label,
    List<(String, String)> items,
    String def, {
    String? help,
  }) {
    final current = _g(key, def);
    final allVals = items.map((e) => e.$1).toSet();
    final dropVal = allVals.contains(current) ? current : def;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, help != null ? 0 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: dropVal,
                isDense: true,
                isExpanded: true,
                items: [
                  for (final (val, lbl) in items)
                    DropdownMenuItem(value: val, child: Text(lbl)),
                ],
                onChanged: (v) {
                  if (v != null) _s(key, v);
                },
              ),
            ),
          ),
          if (help != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
              child: Text(help, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  /// Continuous slider row (floating point).
  Widget _sl(
    String key,
    String label,
    double min,
    double max,
    double def, {
    int decimals = 1,
    String unit = '',
    int? divisions,
  }) {
    final raw = _gd(key, def);
    final val = raw.clamp(min, max);
    final divs = divisions ?? ((max - min) / (decimals == 0 ? 1 : 0.1)).round().clamp(20, 2000);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            Text(
              '${val.toStringAsFixed(decimals)}$unit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ]),
        ),
        Slider(
          value: val,
          min: min,
          max: max,
          divisions: divs,
          onChanged: (v) => setState(() => _conf[key] = v.toStringAsFixed(decimals)),
        ),
      ],
    );
  }

  /// Integer slider row.
  Widget _isl(
    String key,
    String label,
    int min,
    int max,
    int def, {
    String unit = '',
  }) {
    final val = _gi(key, def).clamp(min, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
            Text(
              '$val$unit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ]),
        ),
        Slider(
          value: val.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          onChanged: (v) => setState(() => _conf[key] = v.round().toString()),
        ),
      ],
    );
  }

  // ── Tab contents ───────────────────────────────────────────────────────────

  Widget _videoTab() {
    final debandOn = _gb('deband', false);
    final interpOn = _gb('interpolation', false);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _sectionHeader('Hardware & Output'),
        _dd('hwdec', 'Hardware decoding (hwdec)', [
          ('no', 'no — Software (CPU)'),
          ('auto', 'auto — Auto-select'),
          ('auto-safe', 'auto-safe — Auto (safe APIs only)'),
          ('d3d11va', 'd3d11va — D3D11VA (recommended)'),
          ('d3d11va-copy', 'd3d11va-copy — D3D11VA copy-back'),
          ('dxva2', 'dxva2 — DXVA2'),
          ('dxva2-copy', 'dxva2-copy — DXVA2 copy-back'),
          ('cuda', 'cuda — CUDA (NVIDIA)'),
          ('nvdec', 'nvdec — NVDEC (NVIDIA)'),
          ('nvdec-copy', 'nvdec-copy — NVDEC copy-back'),
          ('d3d12va', 'd3d12va — D3D12VA'),
        ], 'd3d11va'),
        _dd('gpu-api', 'GPU API (gpu-api)', [
          ('auto', 'auto — Auto-select'),
          ('d3d11', 'd3d11 — Direct3D 11 (recommended)'),
          ('vulkan', 'vulkan — Vulkan'),
          ('opengl', 'opengl — OpenGL'),
        ], 'd3d11'),
        _dd('vo', 'Video output driver (vo)', [
          ('gpu', 'gpu — GPU shader pipeline (recommended)'),
          ('gpu-next', 'gpu-next — GPU-next (experimental)'),
          ('direct3d', 'direct3d — Direct3D 9'),
          ('null', 'null — Disabled'),
        ], 'gpu'),

        _sectionHeader('Sync & Motion'),
        _dd('video-sync', 'Video sync mode (video-sync)', [
          ('audio', 'audio — Sync to audio clock'),
          ('display-resample', 'display-resample — Resample audio to display'),
          ('display-resample-vdrop', 'display-resample-vdrop'),
          ('display-vdrop', 'display-vdrop — Drop frames to sync'),
          ('display-adrop', 'display-adrop — Drop audio to sync'),
          ('display-desync', 'display-desync — Free-run with display'),
          ('desync', 'desync — No sync'),
        ], 'display-resample'),
        _sw('interpolation', 'Motion interpolation (interpolation)', false,
            help: 'Smooths motion at the cost of GPU load. Requires display-resample sync.'),
        _dd('tscale', 'Temporal scale filter (tscale)', [
          ('oversample', 'oversample — Oversample (default)'),
          ('linear', 'linear — Linear'),
          ('catmull_rom', 'catmull_rom — Catmull-Rom'),
          ('mitchell', 'mitchell — Mitchell'),
          ('gaussian', 'gaussian — Gaussian'),
          ('bicubic', 'bicubic — Bicubic'),
        ], 'oversample',
            help: interpOn ? null : 'Only relevant when interpolation is on.'),

        _sectionHeader('Scaling Filters'),
        _dd('scale', 'Upscale filter (scale)', [
          ('bilinear', 'bilinear — Bilinear'),
          ('bicubic', 'bicubic — Bicubic'),
          ('lanczos', 'lanczos — Lanczos'),
          ('spline16', 'spline16 — Spline16'),
          ('spline36', 'spline36 — Spline36 (good default)'),
          ('spline64', 'spline64 — Spline64'),
          ('ewa_lanczos', 'ewa_lanczos — EWA Lanczos (Jinc)'),
          ('ewa_lanczossharp', 'ewa_lanczossharp — EWA Lanczos Sharp'),
          ('nearest', 'nearest — Nearest neighbour'),
          ('oversample', 'oversample — Oversample'),
        ], 'spline36'),
        _dd('dscale', 'Downscale filter (dscale)', [
          ('bilinear', 'bilinear — Bilinear (default)'),
          ('bicubic', 'bicubic — Bicubic'),
          ('lanczos', 'lanczos — Lanczos'),
          ('spline16', 'spline16 — Spline16'),
          ('spline36', 'spline36 — Spline36'),
          ('mitchell', 'mitchell — Mitchell'),
        ], 'bilinear'),
        _dd('cscale', 'Chroma upscale filter (cscale)', [
          ('bilinear', 'bilinear — Bilinear (default)'),
          ('bicubic', 'bicubic — Bicubic'),
          ('lanczos', 'lanczos — Lanczos'),
          ('spline16', 'spline16 — Spline16'),
          ('spline36', 'spline36 — Spline36'),
          ('ewa_lanczos', 'ewa_lanczos — EWA Lanczos'),
        ], 'bilinear'),
        _sw('correct-downscaling', 'Correct downscaling (correct-downscaling)', false,
            help: 'Pre-filters when downscaling by more than 2× for sharper output.'),
        _sw('linear-downscaling', 'Linear light downscaling (linear-downscaling)', false),
        _sw('sigmoid-upscaling', 'Sigmoid upscaling (sigmoid-upscaling)', false,
            help: 'Reduces ringing when upscaling.'),
        _dd('dither', 'Dithering (dither)', [
          ('no', 'no — Disabled'),
          ('fruit', 'fruit — Fruit (recommended)'),
          ('ordered', 'ordered — Ordered'),
          ('error-diffusion', 'error-diffusion — Error diffusion'),
        ], 'fruit'),

        _sectionHeader('Debanding'),
        _sw('deband', 'Enable debanding (deband)', false,
            help: 'Reduces gradient banding. May soften fine details.'),
        _isl('deband-iterations', 'Iterations (deband-iterations)', 1, 16, 4,
            unit: ''),
        _isl('deband-threshold', 'Threshold (deband-threshold)', 0, 4096, 64),
        _isl('deband-range', 'Range (deband-range)', 1, 64, 16),
        _isl('deband-grain', 'Grain (deband-grain)', 0, 4096, 48),
        if (!debandOn)
          _infoBox('Enable debanding above to make the four sliders take effect.'),

        _sectionHeader('HDR & Tone Mapping'),
        _sw('hdr-compute-peak', 'Compute HDR peak (hdr-compute-peak)', false),
        _sw('target-colorspace-hint', 'Target colorspace hint (target-colorspace-hint)', false,
            help: 'Pass target colourspace to display; enables native HDR pass-through on Windows.'),
        _dd('tone-mapping', 'Tone mapping algorithm (tone-mapping)', [
          ('auto', 'auto — Auto'),
          ('clip', 'clip — Clip'),
          ('mobius', 'mobius — Mobius'),
          ('reinhard', 'reinhard — Reinhard'),
          ('hable', 'hable — Hable (Filmic)'),
          ('bt.2446a', 'bt.2446a — BT.2446-A'),
          ('gamma', 'gamma — Gamma'),
          ('linear', 'linear — Linear'),
          ('spline', 'spline — Spline'),
          ('bt.2390', 'bt.2390 — BT.2390'),
          ('st2094-40', 'st2094-40 — ST2094-40'),
          ('st2094-10', 'st2094-10 — ST2094-10'),
        ], 'auto'),

        _sectionHeader('Seeking & Misc'),
        _sw('hr-seek', 'High-resolution seeking (hr-seek)', true,
            help: 'Accurate frame-level seeking; slightly slower.'),
        _sw('hr-seek-framedrop', 'Drop frames during HR seek (hr-seek-framedrop)', false),
        _sw('save-position-on-quit', 'Save position on quit (save-position-on-quit)', false),
      ],
    );
  }

  Widget _audioTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _sectionHeader('Playback'),
        _sw('audio-pitch-correction', 'Pitch correction on speed change (audio-pitch-correction)', true,
            help: 'Preserves pitch when playback speed differs from 1×.'),
        _sw('audio-normalize-downmix', 'Normalize downmix (audio-normalize-downmix)', false,
            help: 'Normalise volume when downmixing multichannel to stereo.'),
        _isl('volume-max', 'Maximum volume % (volume-max)', 100, 200, 130, unit: '%'),
        _sl('audio-delay', 'Audio delay (audio-delay)', -10, 10, 0,
            decimals: 2, unit: 's'),

        _sectionHeader('Passthrough (HDMI / S/PDIF)'),
        _infoBox(
          'Pass the compressed bitstream directly to your AV receiver instead of '
          'decoding in software. Enables Dolby Atmos (TrueHD) / DTS:X on compatible hardware.\n'
          'Leave empty to decode in software (default).',
        ),
        _dd('audio-spdif', 'Passthrough codecs (audio-spdif)', [
          ('', 'None — decode in software'),
          ('ac3', 'AC-3 (Dolby Digital)'),
          ('eac3', 'E-AC-3 (Dolby Digital Plus)'),
          ('ac3,eac3', 'AC-3 + E-AC-3'),
          ('truehd', 'TrueHD (Atmos)'),
          ('truehd,eac3', 'TrueHD + E-AC-3'),
          ('truehd,eac3,ac3', 'TrueHD + E-AC-3 + AC-3'),
          ('truehd,eac3,ac3,dts,dts-hd', 'TrueHD + E-AC-3 + AC-3 + DTS + DTS-HD (recommended)'),
          ('dts', 'DTS core'),
          ('dts-hd', 'DTS-HD MA'),
          ('dts,dts-hd', 'DTS + DTS-HD MA'),
          ('truehd,dts,dts-hd', 'TrueHD + DTS + DTS-HD MA'),
        ], ''),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _subtitlesTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _infoBox(
          'sub-ass-override is automatically set at playback time:\n'
          '  • "no" for ASS/SSA tracks — script styles are respected.\n'
          '  • "yes" for plain-text tracks — player styles apply.\n'
          'The value below is used before a track is selected (e.g. for on-screen display).',
        ),
        _dd('sub-ass-override', 'ASS override mode (sub-ass-override)', [
          ('no', 'no — Respect script styles (ASS/SSA)'),
          ('yes', 'yes — Use player styles'),
          ('force', 'force — Force player styles on all tracks'),
          ('scale', 'scale — Keep positioning, override fonts'),
          ('strip', 'strip — Strip all ASS tags'),
        ], 'no'),

        _sectionHeader('Appearance'),
        _infoBox(
          'For non-ASS tracks the Subtitle Appearance controls in the player '
          'overlay take precedence and write these mpv properties at runtime.',
        ),
        _isl('sub-font-size', 'Font size (sub-font-size)', 10, 100, 55),
        _sl('sub-scale', 'Scale (sub-scale)', 0.2, 3.0, 1.0, decimals: 2),
        _isl('sub-margin-y', 'Bottom margin px (sub-margin-y)', 0, 300, 36),
        _isl('sub-margin-x', 'Side margin px (sub-margin-x)', 0, 200, 25),
        _sl('sub-border-size', 'Border size (sub-border-size)', 0, 20, 3.0, decimals: 1),
        _sl('sub-shadow-offset', 'Shadow offset px (sub-shadow-offset)', 0, 20, 0, decimals: 1),
        _sl('sub-blur', 'Blur radius (sub-blur)', 0, 20, 0, decimals: 1),
        _isl('sub-pos', 'Vertical position % (sub-pos)', 0, 150, 100, unit: '%'),

        _sectionHeader('Timing'),
        _sl('sub-delay', 'Subtitle delay (sub-delay)', -30, 30, 0, decimals: 2, unit: 's'),
        _sw('sub-fix-timing', 'Fix timing gaps (sub-fix-timing)', false,
            help: 'Closes small gaps between consecutive subtitles.'),
      ],
    );
  }

  Widget _networkTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _sectionHeader('Connection'),
        _isl('network-timeout', 'Network timeout (network-timeout)', 0, 120, 5, unit: 's'),
        _dd('tls-verify', 'TLS certificate verification (tls-verify)', [
          ('no', 'no — Disabled (accept self-signed)'),
          ('yes', 'yes — Enabled (strict)'),
        ], 'no'),

        _sectionHeader('Cache & Buffer'),
        _sw('cache', 'Enable cache (cache)', true),
        _isl('cache-secs', 'Cache ahead (cache-secs)', 1, 300, 30, unit: 's'),
        _sw('cache-on-disk', 'Cache to disk (cache-on-disk)', false,
            help: 'Caches network streams to disk instead of RAM.'),
        _dd('demuxer-max-bytes', 'Max demuxer buffer (demuxer-max-bytes)', [
          ('8388608', '8 MB'),
          ('16777216', '16 MB'),
          ('33554432', '32 MB (default)'),
          ('67108864', '64 MB'),
          ('134217728', '128 MB'),
          ('268435456', '256 MB'),
          ('536870912', '512 MB'),
        ], '33554432'),
        _dd('demuxer-max-back-bytes', 'Back buffer (demuxer-max-back-bytes)', [
          ('8388608', '8 MB'),
          ('16777216', '16 MB'),
          ('33554432', '32 MB (default)'),
          ('67108864', '64 MB'),
          ('134217728', '128 MB'),
        ], '33554432'),
        _isl('demuxer-readahead-secs', 'Demuxer readahead (demuxer-readahead-secs)', 1, 120, 10, unit: 's'),
      ],
    );
  }

  Widget _appTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _sectionHeader('Display Refresh Rate (Windows)'),
        if (!Platform.isWindows)
          _infoBox('These settings are only applied on Windows.'),
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Match display refresh rate to video'),
          subtitle: Text(
            'Switches primary display Hz to match the video frame rate at playback start. '
            'Best-effort — may not work on all drivers, multi-monitor, or HDR setups.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: _matchHz,
          onChanged: (v) => setState(() => _matchHz = v),
        ),
        SwitchListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text('Only while fullscreen'),
          value: _matchHzFsOnly,
          onChanged: _matchHz ? (v) => setState(() => _matchHzFsOnly = v) : null,
        ),
        const Divider(height: 32),
        _infoBox(
          'Settings on the Video, Audio, Subtitles and Network tabs are saved to '
          'mpv.conf and loaded before each playback session.\n'
          'You can also edit the file directly — custom options are preserved.',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextButton.icon(
            icon: const Icon(Icons.folder_open, size: 18),
            label: const Text('Open config folder'),
            onPressed: () async {
              final path = await MpvConfigService.configFilePath();
              final dir = File(path).parent.path;
              if (Platform.isWindows) {
                await Process.run('explorer', [dir]);
              }
            },
          ),
        ),
      ],
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: SizedBox(
        width: 720,
        height: 640,
        child: Column(
          children: [
            // ── Title bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Player Settings (mpv)',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Cancel',
                  ),
                ],
              ),
            ),
            // ── Tab bar ────────────────────────────────────────────────────
            TabBar(
              controller: _tab,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Video'),
                Tab(text: 'Audio'),
                Tab(text: 'Subtitles'),
                Tab(text: 'Network'),
                Tab(text: 'App'),
              ],
            ),
            const Divider(height: 1),
            // ── Tab views ──────────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _videoTab(),
                  _audioTab(),
                  _subtitlesTab(),
                  _networkTab(),
                  _appTab(),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Action bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Text(
                    'Changes take effect on next playback.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  if (_saving)
                    const SizedBox(
                      width: 80,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else
                    FilledButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
