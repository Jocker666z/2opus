# 2opus

Various audio to OPUS while keeping the tags.

Audio source supported: APE, DSF, FLAC, M4A, MP3, OPUS, WAV, WAVPACK

--------------------------------------------------------------------------------------------------
## Install & update
`curl https://raw.githubusercontent.com/Jocker666z/2opus/master/2opus.sh > /home/$USER/.local/bin/2opus && chmod +rx /home/$USER/.local/bin/2opus`

## Dependencies
`ffmpeg mutagen-inspect opusenc opustags`

## Use
Processes all compatible files in the current directory and his three subdirectories.
```
Options:
  --no_test_source        Skip test of source files.
  --replay-gain           Apply ReplayGain to each track.
  --re_opus               Re-encode OPUS.
  --ape_only              Encode only Monkey's Audio source.
  --dsd_only              Encode only DSD source.
  --flac_only             Encode only FLAC source.
  --m4a_only              Encode only M4A source.
  --mp3_only              Encode only MP3 source.
  --wav_only              Encode only WAV source.
  --wavpack_only          Encode only WAVPACK source.
  -t, --tmp               Cache use /tmp instead /home/$USER/.cache.
  -v, --verbose           More verbose, for debug.

Supported source files:
  * AAC ALAC as .m4a
  * DSD as .dsf
  * FLAC as .flac .ogg
  * MP3 as .mp3
  * WAV as .wav
  * WAVPACK as .wv
```

Notes: 
* OPUS encoding bitrate is `--bitrate 192 --vbr`.
* Converted tags are according with musicbrainz (as far as possible) (https://picard-docs.musicbrainz.org/en/appendices/tag_mapping.html).
* ReplayGain need `rsgain` (https://github.com/complexlogic/rsgain).
* `--re_opus` is a special case, when active this option ignore other types of file.
* `--tmp` increase speed of decoding if you use tmpfs for /tmp directory, but keep in mind the size of this fs.
