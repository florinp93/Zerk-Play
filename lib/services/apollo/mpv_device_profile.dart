Map<String, dynamic> buildMpvDeviceProfile() {
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
        'AudioCodec':
            'ac3,eac3,aac,mp3,flac,truehd,dts,dts-hd,dtshd,opus,vorbis,pcm,pcm_s16le,pcm_s24le',
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
