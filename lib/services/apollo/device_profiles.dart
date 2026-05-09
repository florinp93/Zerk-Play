import 'dart:io';

Map<String, dynamic> buildDeviceProfile({Set<String> passthroughCodecs = const {}}) {
  if (Platform.isAndroid) return buildExoPlayerDeviceProfile();
  return buildMpvDeviceProfile(passthroughCodecs: passthroughCodecs);
}

Map<String, dynamic> buildExoPlayerDeviceProfile() {
  return {
    'Name': 'Zerk Play (Android TV - ExoPlayer)',
    'MaxStreamingBitrate': 120000000,
    'MaxStaticBitrate': 120000000,
    'MusicStreamingTranscodingBitrate': 192000,
    'DirectPlayProfiles': [
      {
        'Container': 'mkv,mp4,m4v,mov,webm,ts,avi,wmv,asf,ogv,3gp',
        'Type': 'Video',
        'VideoCodec': 'h264,hevc,vp8,vp9,av1,mpeg2video,mpeg4',
        'AudioCodec':
            'aac,mp3,ac3,eac3,dts,flac,opus,vorbis,truehd,alac,mp2,pcm,pcm_s16le,pcm_s24le',
      },
      {
        'Container': 'mp3,flac,aac,m4a,ogg,opus,wav,mka,ape,wma',
        'Type': 'Audio',
      },
    ],
    'TranscodingProfiles': [
      {
        'Container': 'ts',
        'Type': 'Video',
        'AudioCodec': 'aac,mp3,ac3',
        'VideoCodec': 'h264',
        'Context': 'Streaming',
        'Protocol': 'hls',
      },
      {
        'Container': 'mp3',
        'Type': 'Audio',
        'AudioCodec': 'mp3',
        'Context': 'Streaming',
        'Protocol': 'http',
      },
    ],
    'ContainerProfiles': [],
    'CodecProfiles': [
      {
        'Type': 'Video',
        'Codec': 'hevc',
        'Conditions': [
          {
            'Condition': 'LessThanEqual',
            'Property': 'VideoBitDepth',
            'Value': '10',
            'IsRequired': 'false',
          },
        ],
      },
      {
        'Type': 'Video',
        'Codec': 'h264',
        'Conditions': [
          {
            'Condition': 'LessThanEqual',
            'Property': 'VideoBitDepth',
            'Value': '10',
            'IsRequired': 'false',
          },
        ],
      },
    ],
    'SubtitleProfiles': [
      {'Format': 'srt', 'Method': 'External'},
      {'Format': 'srt', 'Method': 'Embed'},
      {'Format': 'subrip', 'Method': 'External'},
      {'Format': 'subrip', 'Method': 'Embed'},
      {'Format': 'vtt', 'Method': 'External'},
      {'Format': 'ttml', 'Method': 'External'},
      // ASS/SSA are rendered natively by AssHandler (libass). Declaring External
      // tells Emby to serve the subtitle file directly instead of burning it into
      // the video via transcode, which avoids the slow-transcode timeout issue.
      {'Format': 'ass', 'Method': 'External'},
      {'Format': 'ass', 'Method': 'Embed'},
      {'Format': 'ssa', 'Method': 'External'},
      {'Format': 'ssa', 'Method': 'Embed'},
      // Image-based subtitles still need burn-in since ExoPlayer cannot render them.
      {'Format': 'pgs', 'Method': 'Encode'},
      {'Format': 'pgssub', 'Method': 'Encode'},
      {'Format': 'dvdsub', 'Method': 'Encode'},
    ],
    'ResponseProfiles': [
      {'Type': 'Video', 'Container': 'mkv', 'MimeType': 'video/x-matroska'},
    ],
  };
}

Map<String, dynamic> buildMpvDeviceProfile({Set<String> passthroughCodecs = const {}}) {
  final spdifStr = passthroughCodecs.join(',').toLowerCase();
  final hasTrueHD = spdifStr.contains('truehd');
  final hasDtsHd = spdifStr.contains('dts-hd') || spdifStr.contains('dtshd');

  final audioCodecs = [
    'ac3', 'eac3', 'aac', 'mp3', 'flac',
    if (hasTrueHD) 'truehd',
    'dts',
    if (hasDtsHd) 'dts-hd',
    if (hasDtsHd) 'dtshd',
    'opus', 'vorbis', 'pcm', 'pcm_s16le', 'pcm_s24le',
  ].join(',');

  return {
    'Name': 'Zerk Play (libmpv Windows)',
    'MaxStreamingBitrate': 250000000,
    'MaxStaticBitrate': 250000000,
    'MusicStreamingTranscodingBitrate': 192000,
    'DirectPlayProfiles': [
      {
        'Container': 'mkv,mp4,m4v,mov,avi,webm,ts,wmv,asf,flv,ogv,3gp',
        'Type': 'Video',
        'VideoCodec': 'h264,hevc,vp8,vp9,av1,vc1,mpeg2video,mpeg4',
        'AudioCodec': audioCodecs,
      },
      {
        'Container': 'mp3,flac,aac,m4a,ogg,opus,wav,mka,ape,wma',
        'Type': 'Audio',
      },
    ],
    'TranscodingProfiles': [
      {
        'Container': 'ts',
        'Type': 'Video',
        'AudioCodec': 'aac,mp3',
        'VideoCodec': 'h264',
        'Context': 'Streaming',
        'Protocol': 'hls',
      },
      {
        'Container': 'mp3',
        'Type': 'Audio',
        'AudioCodec': 'mp3',
        'Context': 'Streaming',
        'Protocol': 'http',
      },
    ],
    'ContainerProfiles': [],
    'CodecProfiles': [
      {
        'Type': 'Video',
        'Codec': 'hevc',
        'Conditions': [
          {
            'Condition': 'LessThanEqual',
            'Property': 'VideoBitDepth',
            'Value': '12',
            'IsRequired': 'false',
          },
        ],
      },
      {
        'Type': 'Video',
        'Codec': 'h264',
        'Conditions': [
          {
            'Condition': 'LessThanEqual',
            'Property': 'VideoBitDepth',
            'Value': '10',
            'IsRequired': 'false',
          },
        ],
      },
    ],
    'SubtitleProfiles': [
      {'Format': 'srt', 'Method': 'External'},
      {'Format': 'srt', 'Method': 'Embed'},
      {'Format': 'ass', 'Method': 'External'},
      {'Format': 'ass', 'Method': 'Embed'},
      {'Format': 'ssa', 'Method': 'External'},
      {'Format': 'ssa', 'Method': 'Embed'},
      {'Format': 'pgs', 'Method': 'Embed'},
      {'Format': 'pgssub', 'Method': 'Embed'},
      {'Format': 'dvdsub', 'Method': 'Embed'},
      {'Format': 'vtt', 'Method': 'External'},
      {'Format': 'subrip', 'Method': 'External'},
      {'Format': 'subrip', 'Method': 'Embed'},
    ],
    'ResponseProfiles': [
      {'Type': 'Video', 'Container': 'mkv', 'MimeType': 'video/x-matroska'},
    ],
  };
}
