import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app.dart';
import '../../app/services/app_services.dart';
import '../../core/emby/models/emby_item.dart';
import '../../core/emby/models/emby_media_stream.dart';
import '../../core/emby/models/emby_playback_info.dart';
import '../../l10n/l10n.dart';
import 'playback_page.dart';

final class ItemDetailsPage extends StatefulWidget {
  const ItemDetailsPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<ItemDetailsPage> createState() => _ItemDetailsPageState();
}

final class _ItemDetailsPageState extends State<ItemDetailsPage> {
  AppServices? _services;
  Future<_DetailsData>? _dataFuture;
  EmbyAudioStream? _selectedAudio;
  EmbySubtitleStream? _selectedSubtitle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = _services ??= AppServicesScope.of(context);
    _dataFuture ??= _loadDetails(services);
    _dataFuture!.then((data) {
      final playback = data.playbackInfo;
      if (!mounted || playback == null) return;
      if (_selectedAudio == null && playback.audioStreams.isNotEmpty) {
        setState(() {
          _selectedAudio = _defaultAudio(playback.audioStreams);
          _selectedSubtitle = _defaultSubtitle(playback.subtitleStreams);
        });
      }
    });
  }

  Future<_DetailsData> _loadDetails(AppServices services) async {
    final item = await services.hermes.getItem(widget.itemId);
    if (!_isPlayable(item.type)) {
      return _DetailsData(item: item, playbackInfo: null);
    }
    final playbackInfo = await services.apollo.getPlaybackInfo(item.id);
    return _DetailsData(item: item, playbackInfo: playbackInfo);
  }

  @override
  Widget build(BuildContext context) {
    final services = _services ?? AppServicesScope.of(context);
    return FutureBuilder<_DetailsData>(
      future: _dataFuture ?? _loadDetails(services),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text('${snapshot.error}')),
          );
        }

        final data = snapshot.data!;
        final item = data.item;
        final playbackInfo = data.playbackInfo;

        final imageUri = services.hermes.primaryImageUri(item, maxWidth: 600);
        final progressTicks = item.playbackPositionTicks ?? 0;
        final hasProgress = progressTicks > 0;

        final audioSelection = _selectedAudio ??
            (playbackInfo == null ? null : _defaultAudio(playbackInfo.audioStreams));
        final subtitleSelection = _selectedSubtitle ??
            (playbackInfo == null ? null : _defaultSubtitle(playbackInfo.subtitleStreams));

        return Scaffold(
          appBar: AppBar(title: Text(item.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUri.toString(),
                      width: 240,
                      height: 360,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                        width: 240,
                        height: 360,
                        child: ColoredBox(color: Colors.black12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.productionYear != null)
                          Text(
                            '${item.productionYear}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        const SizedBox(height: 8),
                        if ((item.overview ?? '').isNotEmpty) Text(item.overview!),
                        const SizedBox(height: 16),
                        if (playbackInfo != null) ...[
                          if (hasProgress)
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                FilledButton.icon(
                                  onPressed: audioSelection == null
                                      ? null
                                      : () => _startPlayback(
                                            item: item,
                                            playbackInfo: playbackInfo,
                                            startPositionTicks: progressTicks,
                                            audio: audioSelection,
                                            subtitle: subtitleSelection,
                                          ),
                                  icon: const Icon(Icons.play_arrow),
                                  label: Text(context.l10n.resume),
                                ),
                                OutlinedButton.icon(
                                  onPressed: audioSelection == null
                                      ? null
                                      : () => _startPlayback(
                                            item: item,
                                            playbackInfo: playbackInfo,
                                            startPositionTicks: 0,
                                            audio: audioSelection,
                                            subtitle: subtitleSelection,
                                          ),
                                  icon: const Icon(Icons.restart_alt),
                                  label: Text(context.l10n.startFromBeginning),
                                ),
                              ],
                            )
                          else
                            FilledButton.icon(
                              onPressed: audioSelection == null
                                  ? null
                                  : () => _startPlayback(
                                        item: item,
                                        playbackInfo: playbackInfo,
                                        startPositionTicks: 0,
                                        audio: audioSelection,
                                        subtitle: subtitleSelection,
                                      ),
                              icon: const Icon(Icons.play_arrow),
                              label: Text(context.l10n.play),
                            ),
                          const SizedBox(height: 16),
                          _AudioSubtitleSelectors(
                            playbackInfo: playbackInfo,
                            selectedAudio: audioSelection,
                            selectedSubtitle: subtitleSelection,
                            onAudioChanged: (value) {
                              setState(() => _selectedAudio = value);
                            },
                            onSubtitleChanged: (value) {
                              setState(() => _selectedSubtitle = value);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (item.type == 'Series') _SeriesSeasons(show: item),
              if (item.type == 'Season') _SeasonEpisodes(season: item),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startPlayback({
    required EmbyItem item,
    required EmbyPlaybackInfo playbackInfo,
    required int startPositionTicks,
    required EmbyAudioStream audio,
    required EmbySubtitleStream? subtitle,
  }) async {
    AppUiScope.of(context).lastPlaybackItemId.value = item.id;
    context.go(
      '/play/${item.id}',
      extra: PlaybackArgs(
        item: item,
        playbackInfo: playbackInfo,
        startPositionTicks: startPositionTicks,
        selectedAudio: audio,
        selectedSubtitle: subtitle,
      ),
    );
  }
}

bool _isPlayable(String type) {
  return type == 'Movie' || type == 'Episode' || type == 'Video';
}

final class _DetailsData {
  _DetailsData({required this.item, required this.playbackInfo});

  final EmbyItem item;
  final EmbyPlaybackInfo? playbackInfo;
}

EmbyAudioStream? _defaultAudio(List<EmbyAudioStream> audio) {
  if (audio.isEmpty) return null;
  final preferred = audio.where((e) => e.isDefault).toList(growable: false);
  return preferred.isEmpty ? audio.first : preferred.first;
}

EmbySubtitleStream? _defaultSubtitle(List<EmbySubtitleStream> subtitles) {
  final preferred = subtitles.where((e) => e.isDefault).toList(growable: false);
  return preferred.isEmpty ? null : preferred.first;
}

final class _AudioSubtitleSelectors extends StatelessWidget {
  const _AudioSubtitleSelectors({
    required this.playbackInfo,
    required this.selectedAudio,
    required this.selectedSubtitle,
    required this.onAudioChanged,
    required this.onSubtitleChanged,
  });

  final EmbyPlaybackInfo playbackInfo;
  final EmbyAudioStream? selectedAudio;
  final EmbySubtitleStream? selectedSubtitle;
  final ValueChanged<EmbyAudioStream?> onAudioChanged;
  final ValueChanged<EmbySubtitleStream?> onSubtitleChanged;

  @override
  Widget build(BuildContext context) {
    final audioItems = playbackInfo.audioStreams;
    final subtitleItems = playbackInfo.subtitleStreams;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<EmbyAudioStream>(
          initialValue: selectedAudio,
          decoration: InputDecoration(labelText: context.l10n.audio),
          items: audioItems
              .map(
                (a) => DropdownMenuItem(
                  value: a,
                  child: Text(_audioLabel(a)),
                ),
              )
              .toList(growable: false),
          onChanged: onAudioChanged,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<EmbySubtitleStream?>(
          initialValue: selectedSubtitle,
          decoration: InputDecoration(labelText: context.l10n.subtitles),
          items: <DropdownMenuItem<EmbySubtitleStream?>>[
            DropdownMenuItem(
              value: null,
              child: Text(context.l10n.off),
            ),
            ...subtitleItems.map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(_subtitleLabel(s)),
              ),
            ),
          ],
          onChanged: onSubtitleChanged,
        ),
      ],
    );
  }
}

String _audioLabel(EmbyAudioStream a) {
  final title = (a.title ?? '').trim();
  if (title.isNotEmpty) return title;
  final parts = <String>[];
  if ((a.language ?? '').isNotEmpty) parts.add(a.language!);
  if ((a.codec ?? '').isNotEmpty) parts.add(a.codec!);
  if (a.channels != null) parts.add('${a.channels}ch');
  return parts.isEmpty ? 'Audio ${a.index}' : parts.join(' • ');
}

String _subtitleLabel(EmbySubtitleStream s) {
  final title = (s.title ?? '').trim();
  if (title.isNotEmpty) return title;
  final parts = <String>[];
  if ((s.language ?? '').isNotEmpty) parts.add(s.language!);
  if ((s.codec ?? '').isNotEmpty) parts.add(s.codec!);
  if (s.isForced) parts.add('Forced');
  if (s.isExternal) parts.add('External');
  return parts.isEmpty ? 'Subtitle ${s.index}' : parts.join(' • ');
}

final class _SeriesSeasons extends StatelessWidget {
  const _SeriesSeasons({required this.show});

  final EmbyItem show;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    return FutureBuilder<List<EmbyItem>>(
      future: services.hermes.getSeasons(show.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('${snapshot.error}');
        }
        final seasons = snapshot.data ?? const [];
        if (seasons.isEmpty) return Text(context.l10n.noSeasonsFound);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.seasons, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...seasons.map(
              (season) => ListTile(
                title: Text(season.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ItemDetailsPage(itemId: season.id),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

final class _SeasonEpisodes extends StatelessWidget {
  const _SeasonEpisodes({required this.season});

  final EmbyItem season;

  @override
  Widget build(BuildContext context) {
    final services = AppServicesScope.of(context);
    return FutureBuilder<List<EmbyItem>>(
      future: services.hermes.getEpisodes(season.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Text('${snapshot.error}');
        }
        final episodes = snapshot.data ?? const [];
        if (episodes.isEmpty) return Text(context.l10n.noEpisodesFound);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.episodes, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...episodes.map(
              (ep) => ListTile(
                title: Text(ep.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ItemDetailsPage(itemId: ep.id),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
