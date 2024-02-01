# 2opus

Various audio to OPUS while keeping the tags.

Audio source supported: APE, DSF, FLAC, M4A, WAV, WAVPACK

--------------------------------------------------------------------------------------------------
## Install & update
`curl https://raw.githubusercontent.com/Jocker666z/2opus/master/2opus.sh > /home/$USER/.local/bin/2opus && chmod +rx /home/$USER/.local/bin/2opus`

## Dependencies
`ffmpeg flac mutagen-inspect opusenc opustags wavpack`

## Use
Processes all compatible files in the current directory and his three subdirectories.
```
Options:
  --ape_only              Encode only Monkey's Audio source.
  --dsd_only              Encode only DSD source.
  --flac_only             Encode only FLAC source.
  --m4a_only              Encode only M4A source.
  --wav_only              Encode only WAV source.
  --wavpack_only          Encode only WAVPACK source.
  -v, --verbose           More verbose, for debug.
```
* DSD as .dsf
* FLAC as .flac
* M4A as .m4a
* Monkey's Audio as .ape
* WAVPACK as .wv
* WAV as .wav

Notes: 
* OPUS encoding bitrate is `--bitrate 192 --vbr`.
* Converted tags are according with musicbrainz (as far as possible) (https://picard-docs.musicbrainz.org/en/appendices/tag_mapping.html).
