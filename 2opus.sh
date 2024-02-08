#!/usr/bin/env bash
# shellcheck disable=SC2001,SC2086,SC2207
# 2opus
# Various lossless to OPUS while keeping the tags.
# \(^o^)/ 
#
# Author : Romain Barbarot
# https://github.com/Jocker666z/2opus/
# Licence : unlicense

# Search & populate array with source files
search_source_files() {
local codec_test

mapfile -t lst_audio_src < <(find "$PWD" -maxdepth 3 -type f -regextype posix-egrep \
								-iregex '.*\.('$input_ext')$' 2>/dev/null | sort)

# Only clean
for i in "${!lst_audio_src[@]}"; do

	if [[ "${ape_only}" = "1" ]] \
	&& [[ "${lst_audio_src[i]##*.}" != "ape" ]]; then
			unset "lst_audio_src[i]"
	fi

	if [[ "${dsd_only}" = "1" ]] \
	&& [[ "${lst_audio_src[i]##*.}" != "dsf" ]]; then
			unset "lst_audio_src[i]"
	fi

	if [[ "${flac_only}" = "1" ]] \
	&& [[ "${lst_audio_src[i]##*.}" != "flac" \
	   && "${lst_audio_src[i]##*.}" != "ogg" ]]; then
			unset "lst_audio_src[i]"
	fi
	# Keep only FLAC codec in ogg
	if [[ "${lst_audio_src[i]##*.}" = "ogg" ]]; then
		codec_test=$(ffprobe -v error -select_streams a:0 \
			-show_entries stream=codec_name -of csv=s=x:p=0 \
			"${lst_audio_src[i]%.*}.ogg" )
		if [[ "$codec_test" != "flac" ]]; then
			unset "lst_audio_src[i]"
		fi
	fi

	if [[ "${M4A_only}" = "1" ]] \
	&& [[ "${lst_audio_src[i]##*.}" != "m4a" ]]; then
			unset "lst_audio_src[i]"
	fi

	if [[ "${MP3_only}" = "1" ]] \
	&& [[ "${lst_audio_src[i]##*.}" != "mp3" ]]; then
			unset "lst_audio_src[i]"
	fi

	if [[ "${wav_only}" = "1" ]] \
	&& [[ "${lst_audio_src[i]##*.}" != "wav" ]]; then
			unset "lst_audio_src[i]"
	fi

	if [[ "${wavpack_only}" = "1" ]] \
	&& [[ "${lst_audio_src[i]##*.}" != "wv" ]]; then
			unset "lst_audio_src[i]"
	fi

done
}
# Verify source integrity
test_source() {
local test_counter

test_counter="0"

# Test
for file in "${lst_audio_src[@]}"; do

	# Progress
	if ! [[ "$verbose" = "1" ]]; then
		test_counter=$((test_counter+1))
		if [[ "${#lst_audio_src[@]}" = "1" ]]; then
			echo -ne "${test_counter}/${#lst_audio_src[@]} source file is being tested"\\r
		else
			echo -ne "${test_counter}/${#lst_audio_src[@]} source files are being tested"\\r
		fi
	fi

	(

	ffmpeg -v error -i "$file" \
		-vn -sn -dn -max_muxing_queue_size 9999 \
		-f null - 2>"${cache_dir}/${file##*/}.decode_error.log"

	# Ignore ffmpeg non-blocking errors
	if [ -s "${cache_dir}/${file##*/}.decode_error.log" ]; then
		# [mjpeg @ ...] unable to decode APP fields...
		if < "${cache_dir}/${file##*/}.decode_error.log" \
			grep  -E "mjpeg.*APP fields" &>/dev/null; then
			rm "${cache_dir}/${file##*/}.decode_error.log"
		fi
	fi

	) &
	if [[ $(jobs -r -p | wc -l) -ge $nproc ]]; then
		wait -n
	fi

done
wait

# Test if error generated
for file in "${lst_audio_src[@]}"; do

	# Errors validation
	if [ -s "${cache_dir}/${file##*/}.decode_error.log" ]; then
		mv "${cache_dir}/${file##*/}.decode_error.log" "${file}.decode_error.log"
		lst_audio_src_rejected+=( "$file" )
	else
		rm "${cache_dir}/${file##*/}.decode_error.log"  2>/dev/null
		lst_audio_src_pass+=( "$file" )
	fi

done


# Progress end
if ! [[ "$verbose" = "1" ]]; then
	tput hpa 0; tput el
	if (( "${#lst_audio_src_rejected[@]}" )); then
		if [[ "${#lst_audio_src[@]}" = "1" ]]; then
			echo "${test_counter} source file tested ~ ${#lst_audio_src_rejected[@]} in error (log generated)"
		else
			echo "${test_counter} source files tested ~ ${#lst_audio_src_rejected[@]} in error (log generated)"
		fi
	else
		if [[ "${#lst_audio_src[@]}" = "1" ]]; then
			echo "${test_counter} source file tested"
		else
			echo "${test_counter} source files tested"
		fi
	fi
fi

# All source files size record
total_source_files_size=$(calc_files_size "${lst_audio_src_pass[@]}")
# Individual source file size record
for file in "${lst_audio_src_pass[@]}"; do
	file_source_files_size+=( "$(get_files_size_bytes "${file}")" )
done
}
# Decode source
decode_source() {
local decode_counter

decode_counter="0"

for file in "${lst_audio_src_pass[@]}"; do
	(

	if [[ "${file##*.}" != "flac" ]] \
	&& [[ "${file##*.}" != "ogg" ]] \
	&& [[ "${file##*.}" != "wav" ]]; then
		if [[ "${file##*.}" = "dsf" ]]; then
			ffmpeg $ffmpeg_log_lvl -y -i "$file" \
				-c:a pcm_s24le -ar 384000 "${cache_dir}/${file##*/}.wav"
		else
			ffmpeg $ffmpeg_log_lvl -y -i "$file" "${cache_dir}/${file##*/}.wav"
		fi
	fi

	) &
	if [[ $(jobs -r -p | wc -l) -ge $nproc ]]; then
		wait -n
	fi

	# OPUS target array
	if [[ "${file##*.}" = "flac" ]] \
	|| [[ "${file##*.}" = "ogg" ]] \
	|| [[ "${file##*.}" = "wav" ]]; then
		lst_audio_wav_decoded+=( "$file" )
	else
		decode_counter=$((decode_counter+1))
		lst_audio_wav_decoded+=( "${cache_dir}/${file##*/}.wav" )
	fi

	# Progress
	if ! [[ "$verbose" = "1" ]]; then
		if [[ "${#lst_audio_src_pass[@]}" = "1" ]]; then
			echo -ne "${decode_counter}/${#lst_audio_src_pass[@]} source file decoded"\\r
		else
			echo -ne "${decode_counter}/${#lst_audio_src_pass[@]} source files decoded"\\r
		fi
	fi

done
wait

# Progress end
if [[ "$verbose" != "1" ]];then
	tput hpa 0; tput el
	if [[ "${#lst_audio_src_pass[@]}" = "1" ]]; then
		echo "${decode_counter} source file decoded"
	else
		echo "${decode_counter} source files decoded"
	fi
fi
}
# Convert tag to VORBIS
tags_2_opus() {
local cover_test
local cover_ext
local tag_label
local grab_tag_counter

grab_tag_counter="0"

for file in "${lst_audio_opus_encoded[@]}"; do

	# Reset
	unset source_tag
	unset source_tag_temp
	unset source_tag_temp1
	unset source_tag_temp2
	unset tag_name
	unset tag_label
	unset tag_trick

	# Target file
	if [[ -s "${file%.*}.ape" ]]; then
		file="${file%.*}.ape"
	elif [[ -s "${file%.*}.dsf" ]]; then
		file="${file%.*}.dsf"
	elif [[ -s "${file%.*}.flac" ]]; then
		file="${file%.*}.flac"
	elif [[ -s "${file%.*}.m4a" ]]; then
		file="${file%.*}.m4a"
	elif [[ -s "${file%.*}.mp3" ]]; then
		file="${file%.*}.mp3"
	elif [[ -s "${file%.*}.ogg" ]]; then
		file="${file%.*}.ogg"
	elif [[ -s "${file%.*}.wv" ]]; then
		file="${file%.*}.wv"
	fi

	# Source file tags array
	mapfile -t source_tag < <( mutagen-inspect "$file" )
	# itune need clean
	if [[ -s "${file%.*}.m4a" ]]; then
		for i in "${!source_tag[@]}"; do
			source_tag[i]="${source_tag[i]//MP4FreeForm(b\'/}"
			source_tag[i]="${source_tag[i]//\', <AtomDataType.UTF8: 1>)/}"
			if [[ "${source_tag[i]}" = "disk="* ]] \
			|| [[ "${source_tag[i]}" = *"trkn="* ]]; then
				source_tag[i]="${source_tag[i]//disk=(/disk=}"
				source_tag[i]="${source_tag[i]//trkn=(/trkn=}"
				source_tag[i]="${source_tag[i]//, //}"
				source_tag[i]="${source_tag[i]//)/}"
			fi
		done
	fi
	# Try to extract cover, if no cover in directory
	if [[ ! -e "${file%/*}"/cover.jpg ]] \
	&& [[ ! -e "${file%/*}"/cover.png ]]; then
		cover_test=$(ffprobe -v error -select_streams v:0 \
					-show_entries stream=codec_name -of csv=s=x:p=0 \
					"$file" 2>/dev/null)
		if [[ -n "$cover_test" ]]; then
			if [[ "$cover_test" = "png" ]]; then
				cover_ext="png"
			elif [[ "$cover_test" = *"jpeg"* ]]; then
				cover_ext="jpg"
			fi
			ffmpeg $ffmpeg_log_lvl -n -i "$file" \
				"${file%/*}"/cover."$cover_ext" 2>/dev/null
		fi
	fi

	# Remove empty tag label= & sort
	mapfile -t source_tag < <( printf '%s\n' "${source_tag[@]}" \
								| grep "=" )

	# Substitution
	for i in "${!source_tag[@]}"; do
		# MusicBrainz internal name
		source_tag[i]="${source_tag[i]//albumartistsort=/ALBUMARTISTSORT=}"
		source_tag[i]="${source_tag[i]//artistsort=/ARTISTSORT=}"
		source_tag[i]="${source_tag[i]//musicbrainz_albumid=/MUSICBRAINZ_ALBUMID=}"
		source_tag[i]="${source_tag[i]//musicbrainz_artistid=/MUSICBRAINZ_ARTISTID=}"
		source_tag[i]="${source_tag[i]//musicbrainz_recordingid=/MUSICBRAINZ_TRACKID=}"
		source_tag[i]="${source_tag[i]//musicbrainz_releasegroupid=/MUSICBRAINZ_RELEASEGROUPID=}"
		source_tag[i]="${source_tag[i]//originalyear=/ORIGINALYEAR=}"
		source_tag[i]="${source_tag[i]//replaygain_album_gain=/REPLAYGAIN_ALBUM_GAIN=}"
		source_tag[i]="${source_tag[i]//replaygain_album_peak=/REPLAYGAIN_ALBUM_PEAK=}"
		source_tag[i]="${source_tag[i]//replaygain_track_gain=/REPLAYGAIN_TRACK_GAIN=}"
		source_tag[i]="${source_tag[i]//replaygain_track_peak=/REPLAYGAIN_TRACK_PEAK=}"

		# APEv2
		source_tag[i]="${source_tag[i]//Album Artist=/ALBUMARTIST=}"
		source_tag[i]="${source_tag[i]//Arranger=/ARRANGER=}"
		source_tag[i]="${source_tag[i]//Barcode=/BARCODE=}"
		source_tag[i]="${source_tag[i]//CatalogNumber=/CATALOGNUMBER=}"
		source_tag[i]="${source_tag[i]//Comment=/COMMENT=}"
		source_tag[i]="${source_tag[i]//Compilation=/COMPILATION=}"
		source_tag[i]="${source_tag[i]//Composer=/COMPOSER=}"
		source_tag[i]="${source_tag[i]//Conductor=/CONDUCTOR=}"
		source_tag[i]="${source_tag[i]//Copyright=/COPYRIGHT=}"
		source_tag[i]="${source_tag[i]//Year=/DATE=}"
		source_tag[i]="${source_tag[i]//Director=/DIRECTOR=}"
		source_tag[i]="${source_tag[i]//Disc=/DISCNUMBER=}"
		source_tag[i]="${source_tag[i]//DiscSubtitle=/DISCSUBTITLE=}"
		source_tag[i]="${source_tag[i]//DJMixer=/DJMIXER=}"
		source_tag[i]="${source_tag[i]//Engineer=/ENGINEER=}"
		source_tag[i]="${source_tag[i]//Genre=/GENRE=}"
		source_tag[i]="${source_tag[i]//Grouping=/GROUPING=}"
		source_tag[i]="${source_tag[i]//Label=/LABEL=}"
		source_tag[i]="${source_tag[i]//Language=/LANGUAGE=}"
		source_tag[i]="${source_tag[i]//Lyricist=/LYRICIST=}"
		source_tag[i]="${source_tag[i]//Lyrics=/LYRICS=}"
		source_tag[i]="${source_tag[i]//Media=/MEDIA=}"
		source_tag[i]="${source_tag[i]//Mixer=/MIXER=}"
		source_tag[i]="${source_tag[i]//Mood=/MOOD=}"
		source_tag[i]="${source_tag[i]//Performer=/PERFORMER=}"
		source_tag[i]="${source_tag[i]//MUSICBRAINZ_ALBUMSTATUS=/RELEASESTATUS=}"
		source_tag[i]="${source_tag[i]//MUSICBRAINZ_ALBUMTYPE=/RELEASETYPE=}"
		source_tag[i]="${source_tag[i]//MixArtist=/REMIXER=}"
		source_tag[i]="${source_tag[i]//Script=/SCRIPT=}"
		source_tag[i]="${source_tag[i]//Subtitle=/SUBTITLE=}"
		source_tag[i]="${source_tag[i]//Title=/TITLE=}"
		source_tag[i]="${source_tag[i]//Track=/TRACKNUMBER=}"
		source_tag[i]="${source_tag[i]//Weblink=/WEBSITE=}"
		source_tag[i]="${source_tag[i]//WEBSITE=/Weblink=}"
		source_tag[i]="${source_tag[i]//Writer=/WRITER=}"
		# ID3v2
		source_tag[i]="${source_tag[i]//TALB=/ALBUM=}"
		source_tag[i]="${source_tag[i]//TBPM=/BPM=}"
		source_tag[i]="${source_tag[i]//TDOR=/ORIGINALDATE=}"
		source_tag[i]="${source_tag[i]//TDRC=/DATE=}"
		source_tag[i]="${source_tag[i]//TEXT=/LYRICIST=}"
		source_tag[i]="${source_tag[i]//TIT2=/TITLE=}"
		source_tag[i]="${source_tag[i]//TMED=/MEDIA=}"
		source_tag[i]="${source_tag[i]//TPOS=/DISCNUMBER=}"
		source_tag[i]="${source_tag[i]//TPE1=/ARTIST=}"
		source_tag[i]="${source_tag[i]//TPE2=/ALBUMARTIST=}"
		source_tag[i]="${source_tag[i]//TPUB=/LABEL=}"
		source_tag[i]="${source_tag[i]//TRCK=/TRACKNUMBER=}"
		source_tag[i]="${source_tag[i]//TSO2=/ALBUMARTISTSORT=}"
		source_tag[i]="${source_tag[i]//TSOP=/ARTISTSORT=}"
		source_tag[i]="${source_tag[i]//TSRC=/ISRC=}"
		source_tag[i]="${source_tag[i]//TXXX=Acoustid Id=/ACOUSTID_ID=}"
		source_tag[i]="${source_tag[i]//TXXX=Acoustid Fingerprint=/ACOUSTID_FINGERPRINT=}"
		source_tag[i]="${source_tag[i]//TXXX=ARTISTS=/ARTISTS=}"
		source_tag[i]="${source_tag[i]//TXXX=ASIN=/ASIN=}"
		source_tag[i]="${source_tag[i]//TXXX=BARCODE=/BARCODE=}"
		source_tag[i]="${source_tag[i]//TXXX=CATALOGNUMBER=/CATALOGNUMBER=}"
		source_tag[i]="${source_tag[i]//TXXX=MusicBrainz Album Id=/MUSICBRAINZ_ALBUMID=}"
		source_tag[i]="${source_tag[i]//TXXX=MusicBrainz Album Artist Id=/MUSICBRAINZ_ALBUMARTISTID=}"
		source_tag[i]="${source_tag[i]//TXXX=MusicBrainz Album Status=/RELEASESTATUS=}"
		source_tag[i]="${source_tag[i]//TXXX=MusicBrainz Album Type=/RELEASETYPE=}"
		source_tag[i]="${source_tag[i]//TXXX=MusicBrainz Artist Id=/MUSICBRAINZ_ARTISTID=}"
		source_tag[i]="${source_tag[i]//TXXX=MusicBrainz Album Release Country=/RELEASECOUNTRY=}"
		source_tag[i]="${source_tag[i]//TXXX=MusicBrainz Release Group Id=/MUSICBRAINZ_RELEASEGROUPID=}"
		source_tag[i]="${source_tag[i]//TXXX=MusicBrainz Release Track Id=/MUSICBRAINZ_RELEASETRACKID=}"
		source_tag[i]="${source_tag[i]//TXXX=SCRIPT=/SCRIPT=}"
		source_tag[i]="${source_tag[i]//UFID=/MUSICBRAINZ_TRACKID=}"
		# iTune
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:Acoustid Id=/ACOUSTID_ID=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:Acoustid Fingerprint=/ACOUSTID_FINGERPRINT=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:ARTISTS=/ARTISTS=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:ASIN=/ASIN=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:BARCODE=/BARCODE=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:CATALOGNUMBER=/CATALOGNUMBER=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:ISRC=/ISRC=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:LABEL=/LABEL=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:MEDIA=/MEDIA=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:MusicBrainz Album Artist Id=/MUSICBRAINZ_ALBUMARTISTID=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:MusicBrainz Album Id=/MUSICBRAINZ_ALBUMID=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:MusicBrainz Album Release Country=/RELEASECOUNTRY=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:MusicBrainz Album Status=/RELEASESTATUS=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:MusicBrainz Album Type=/RELEASETYPE=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:MusicBrainz Artist Id=/MUSICBRAINZ_ARTISTID=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:MusicBrainz Release Group Id=/MUSICBRAINZ_RELEASEGROUPID=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:MusicBrainz Release Track Id=/MUSICBRAINZ_RELEASETRACKID=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:MusicBrainz Track Id=/MUSICBRAINZ_TRACKID=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:SCRIPT=/SCRIPT=}"
		source_tag[i]="${source_tag[i]//©alb=/ALBUM=}"
		source_tag[i]="${source_tag[i]//©ART=/ARTIST=}"
		source_tag[i]="${source_tag[i]//©day=/DATE=}"
		source_tag[i]="${source_tag[i]//©nam=/TITLE=}"
		source_tag[i]="${source_tag[i]//aART=/ALBUMARTIST=}"
		source_tag[i]="${source_tag[i]//disk=/DISCNUMBER=}"
		source_tag[i]="${source_tag[i]//soaa=/ALBUMARTISTSORT=}"
		source_tag[i]="${source_tag[i]//soar=/ARTISTSORT=}"
		source_tag[i]="${source_tag[i]//trkn=/TRACKNUMBER=}"
		# Waste fix
		shopt -s nocasematch
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:originaldate=/ORIGINALDATE=}"
		source_tag[i]="${source_tag[i]//----:com.apple.iTunes:originalyear=/ORIGINALYEAR=}"
		source_tag[i]="${source_tag[i]//date=/DATE=}"
		source_tag[i]="${source_tag[i]//originaldate=/ORIGINALDATE=}"
		source_tag[i]="${source_tag[i]//TXXX=originalyear=/ORIGINALYEAR=}"
		shopt -u nocasematch
	done


	# Array tag name & label
	mapfile -t tag_name < <( printf '%s\n' "${source_tag[@]}" | awk -F "=" '{print $1}' )
	mapfile -t tag_label < <( printf '%s\n' "${source_tag[@]}" | cut -f2- -d'=' )

	# Whitelist parsing
	for i in "${!tag_name[@]}"; do
		for tag in "${Vorbis_whitelist[@]}"; do
			# Vorbis std
			if [[ "${tag_name[i],,}" = "${tag,,}" ]] \
			&& [[ -n "${tag_label[i]// }" ]]; then

				# Picard std
				if [[ "${tag}" = "TRACKNUMBER" ]] \
				&& [[ "${tag_label[i]}" = *"/"* ]]; then
					source_tag+=( "TOTALTRACKS=\"${tag_label[i]#*/}\"" )
				fi
				if [[ "${tag}" = "DISCNUMBER" ]] \
				&& [[ "${tag_label[i]}" = *"/"* ]]; then
					source_tag+=( "TOTALDISCS=\"${tag_label[i]#*/}\"" )
				fi
				if [[ "${tag}" = "TRACKNUMBER" ]] \
				|| [[ "${tag}" = "DISCNUMBER" ]]; then
					tag_label[i]="${tag_label[i]%/*}"
				fi

				if [[ "${tag}" = "ARTISTS" ]] \
				&& [[ "${tag_label[i]}" = *"/"* ]]; then
					mapfile -t tag_trick < <( echo "${tag_label[i]//\//|}" \
									| tr "|" "\n" )
					for type in "${tag_trick[@]}"; do
						source_tag+=( "ARTISTS=\"${type}\"" )
					done
				elif [[ "${tag}" = "MUSICBRAINZ_ARTISTID" ]] \
				&& [[ "${tag_label[i]}" = *"/"* ]]; then
					mapfile -t tag_trick < <( echo "${tag_label[i]//\//|}" \
									| tr "|" "\n" )
					for type in "${tag_trick[@]}"; do
						source_tag+=( "MUSICBRAINZ_ARTISTID=\"${type}\"" )
					done
				elif [[ "${tag}" = "ISRC" ]] \
				&& [[ "${tag_label[i]}" = *"/"* ]]; then
					mapfile -t tag_trick < <( echo "${tag_label[i]//\//|}" \
									| tr "|" "\n" )
					for type in "${tag_trick[@]}"; do
						source_tag+=( "ISRC=\"${type}\"" )
					done
				elif [[ "${tag}" = "LABEL" ]] \
				&& [[ "${tag_label[i]}" = *"/"* ]]; then
					mapfile -t tag_trick < <( echo "${tag_label[i]//\//|}" \
									| tr "|" "\n" )
					for type in "${tag_trick[@]}"; do
						source_tag+=( "LABEL=\"${type}\"" )
					done
				elif [[ "${tag}" = "MUSICBRAINZ_TRACKID" ]] \
				&& [[ "${tag_label[i]}" = *"'"* ]]; then
					tag_trick=$(echo "${tag_label[i]}" \
								| cut  -d "'" -f2)
					source_tag+=( "MUSICBRAINZ_TRACKID=\"${tag_trick}\"" )
				elif [[ "${tag}" = "MUSICBRAINZ_ALBUMARTISTID" ]] \
				&& [[ "${tag_label[i]}" = *"/"* ]]; then
					mapfile -t tag_trick < <( echo "${tag_label[i]//\//|}" \
									| tr "|" "\n" )
					for type in "${tag_trick[@]}"; do
						source_tag+=( "MUSICBRAINZ_ALBUMARTISTID=\"${type}\"" )
					done
				elif [[ "${tag}" = "RELEASETYPE" ]] \
				&& [[ "${tag_label[i]}" = *"/"* ]]; then
					mapfile -t tag_trick < <( echo "${tag_label[i]//\//|}" \
									| tr "|" "\n" )
					for type in "${tag_trick[@]}"; do
						source_tag+=( "RELEASETYPE=\"${type}\"" )
					done
				else
					# Prevent double quote error
					tag_label[i]="${tag_label[i]//\"/\\\"}"
					# Array of tag
					source_tag[i]="${tag}=\"${tag_label[i]}\""
				fi

				continue 2
			# reject
			else
				unset "source_tag[i]"
			fi
		done
	done

	# Remove duplicate tags
	mapfile -t source_tag < <( printf '%s\n' "${source_tag[@]}" | uniq -u )

	# tag argument
	target_tags_construct=$(printf '%s\n' "${source_tag[@]}" \
							| awk 1 ORS=' -s ')
	target_tags_construct="-s ${target_tags_construct% -s }"
	lst_audio_opus_target_tags+=( "$target_tags_construct" )

	# Progress
	if ! [[ "$verbose" = "1" ]]; then
		grab_tag_counter=$((grab_tag_counter+1))
		if [[ "${#lst_audio_opus_encoded[@]}" = "1" ]]; then
			echo -ne "${grab_tag_counter}/${#lst_audio_opus_encoded[@]} tag is being converted to vorbis comment"\\r
		else
			echo -ne "${grab_tag_counter}/${#lst_audio_opus_encoded[@]} tags is being converted to vorbis comment"\\r
		fi
	fi
done

# Progress end
if ! [[ "$verbose" = "1" ]]; then
	tput hpa 0; tput el
	if [[ "${#lst_audio_opus_encoded[@]}" = "1" ]]; then
		echo "${grab_tag_counter} tag is being converted to vorbis comment"
	else
		echo "${grab_tag_counter} tags is being converted to vorbis comment"
	fi
fi
}
# OPUS - Encode
encode_opus() {
local compress_counter

compress_counter="0"

# Encode OPUS
for i in "${!lst_audio_src_pass[@]}"; do
	(
	if [[ "$verbose" = "1" ]]; then
		opusenc \
		--bitrate "$opus_bitrate" --vbr \
			"${lst_audio_wav_decoded[i]}" "${lst_audio_src_pass[i]%.*}".opus &>/dev/null
	else
		opusenc \
		--bitrate "$opus_bitrate" --vbr \
			"${lst_audio_wav_decoded[i]}" "${lst_audio_src_pass[i]%.*}".opus &>/dev/null
	fi
	) &
	if [[ $(jobs -r -p | wc -l) -ge $nproc ]]; then
		wait -n
	fi

	# Progress
	if ! [[ "$verbose" = "1" ]]; then
		compress_counter=$((compress_counter+1))
		if [[ "${#lst_audio_wav_decoded[@]}" = "1" ]]; then
			echo -ne "${compress_counter}/${#lst_audio_wav_decoded[@]} opus file is being encoded"\\r
		else
			echo -ne "${compress_counter}/${#lst_audio_wav_decoded[@]} opus files are being encoded"\\r
		fi
	fi
done
wait

# Progress end
if ! [[ "$verbose" = "1" ]]; then
	tput hpa 0; tput el
	if [[ "${#lst_audio_wav_decoded[@]}" = "1" ]]; then
		echo "${compress_counter} opus file encoded"
	else
		echo "${compress_counter} opus files encoded"
	fi
fi

# Clean + target array
for i in "${!lst_audio_src_pass[@]}"; do
	# Array of ape target
	lst_audio_opus_encoded+=( "${lst_audio_src_pass[i]%.*}.opus" )

	# Remove temp wav files
	if [[ "${lst_audio_src[i]##*.}" != "wav" ]] \
	&& [[ "${lst_audio_src[i]##*.}" != "ogg" ]] \
	&& [[ "${lst_audio_src[i]##*.}" != "flac" ]]; then
		rm -f "${lst_audio_wav_decoded[i]%.*}.wav" 2>/dev/null
	fi
done
}
# OPUS - Tag
tag_opus() {
local tag_counter

tag_counter="0"

for i in "${!lst_audio_opus_encoded[@]}"; do
	(
	if [[ "$verbose" = "1" ]]; then
		eval opustags -D \
				-i "\"${lst_audio_opus_encoded[i]%.*}.opus\"" \
				"${lst_audio_opus_target_tags[i]}"
	else
		eval opustags -D \
				-i "\"${lst_audio_opus_encoded[i]%.*}.opus\"" \
				"${lst_audio_opus_target_tags[i]}" &>/dev/null
	fi
	) &
	if [[ $(jobs -r -p | wc -l) -ge $nproc ]]; then
		wait -n
	fi

	# Progress
	if ! [[ "$verbose" = "1" ]]; then
		tag_counter=$((tag_counter+1))
		if [[ "${#lst_audio_wav_decoded[@]}" = "1" ]]; then
			echo -ne "${tag_counter}/${#lst_audio_opus_encoded[@]} opus file is being tagged"\\r
		else
			echo -ne "${tag_counter}/${#lst_audio_opus_encoded[@]} opus files are being tagged"\\r
		fi
	fi
done
wait

# Progress end
if ! [[ "$verbose" = "1" ]]; then
	tput hpa 0; tput el
	if [[ "${#lst_audio_wav_decoded[@]}" = "1" ]]; then
		echo "${tag_counter} opus file tagged"
	else
		echo "${tag_counter} opus files tagged"
	fi
fi
}
# Total size calculation in MB - Input must be in bytes
calc_files_size() {
local files
local size
local size_in_mb

files=("$@")

if (( "${#files[@]}" )); then
	# Get size in bytes
	if ! [[ "${files[-1]}" =~ ^[0-9]+$ ]]; then
		size=$(wc -c "${files[@]}" | tail -1 | awk '{print $1;}')
	else
		size="${files[-1]}"
	fi
	# Mb convert
	size_in_mb=$(bc <<< "scale=1; $size / 1024 / 1024" | sed 's!\.0*$!!')
else
	size_in_mb="0"
fi

# If string start by "." add lead 0
if [[ "${size_in_mb:0:1}" == "." ]]; then
	size_in_mb="0$size_in_mb"
fi

# If GB not display float
size_in_mb_integer="${size_in_mb%%.*}"
if [[ "${#size_in_mb_integer}" -ge "4" ]]; then
	size_in_mb="$size_in_mb_integer"
fi

echo "$size_in_mb"
}
# Get file size in bytes
get_files_size_bytes() {
local files
local size
files=("$@")

if (( "${#files[@]}" )); then
	# Get size in bytes
	size=$(wc -c "${files[@]}" | tail -1 | awk '{print $1;}')
fi

echo "$size"
}
# Percentage calculation
calc_percent() {
local total
local value
local perc

value="$1"
total="$2"

if [[ "$value" = "$total" ]]; then
	echo "00.00"
else
	# Percentage calculation
	perc=$(bc <<< "scale=4; ($total - $value)/$value * 100")
	# If string start by "." or "-." add lead 0
	if [[ "${perc:0:1}" == "." ]] || [[ "${perc:0:2}" == "-." ]]; then
		if [[ "${perc:0:2}" == "-." ]]; then
			perc="${perc/-./-0.}"
		else
			perc="${perc/./+0.}"
		fi
	fi
	# If string start by integer add lead +
	if [[ "${perc:0:1}" =~ ^[0-9]+$ ]]; then
			perc="+${perc}"
	fi
	# Keep only 5 first digit
	perc="${perc:0:5}"

	echo "$perc"
fi
}
# Display trick - print term tuncate
display_list_truncate() {
local list
local term_widh_truncate

list=("$@")

term_widh_truncate=$(stty size | awk '{print $2}' | awk '{ print $1 - 8 }')

for line in "${list[@]}"; do
	if [[ "${#line}" -gt "$term_widh_truncate" ]]; then
		echo -e "  $line" | cut -c 1-"$term_widh_truncate" | awk '{print $0"..."}'
	else
		echo -e "  $line"
	fi
done
}
# Summary of processing
summary_of_processing() {
local time_formated
local file_target_files_size
local file_diff_percentage
local file_path_truncate
local total_target_files_size
local total_diff_size
local total_diff_percentage

if (( "${#lst_audio_src[@]}" )); then
	time_formated="$((SECONDS/3600))h$((SECONDS%3600/60))m$((SECONDS%60))s"

	# All files pass size stats & label
	if (( "${#lst_audio_src_pass[@]}" )); then
		for i in "${!lst_audio_src_pass[@]}"; do
			# Make statistics of indidual processed files
			file_target_files_size=$(get_files_size_bytes "${lst_audio_opus_encoded[i]}")
			file_diff_percentage=$(calc_percent "${file_source_files_size[i]}" "$file_target_files_size")
			filesPassSizeReduction+=( "$file_diff_percentage" )
			file_path_truncate=$(echo "${lst_audio_opus_encoded[i]}" | rev | cut -d'/' -f-3 | rev)
			filesPassLabel+=( "(${filesPassSizeReduction[i]}%) ~ .${file_path_truncate}" )
		done
	fi
	# All files rejected size label
	if (( "${#lst_audio_src_rejected[@]}" )); then
		for i in "${!lst_audio_src_rejected[@]}"; do
			file_path_truncate=$(echo "${lst_audio_src_rejected[i]}" | rev | cut -d'/' -f-3 | rev)
			filesRejectedLabel+=( ".${file_path_truncate}" )
		done
	fi
	# Total files size stats
	total_target_files_size=$(calc_files_size "${lst_audio_opus_encoded[@]}")
	total_diff_size=$(bc <<< "scale=0; ($total_target_files_size - $total_source_files_size)" \
						| sed -r 's/^(-?)\./\10./')
	total_diff_percentage=$(calc_percent "$total_source_files_size" "$total_target_files_size")

	# Print list of files stats
	if (( "${#lst_audio_src_pass[@]}" )); then
		echo
		echo "File(s) created:"
		display_list_truncate "${filesPassLabel[@]}"
	fi
	# Print list of files reject
	if (( "${#lst_audio_src_rejected[@]}" )); then
		echo
		echo "File(s) in error:"
		display_list_truncate "${filesRejectedLabel[@]}"
	fi
	# Print all files stats
	echo
	echo "${#lst_audio_opus_encoded[@]}/${#lst_audio_src[@]} file(s) encoded to OPUS for a total of ${total_target_files_size}Mb."
	echo "${total_diff_percentage}% difference with the source files, ${total_diff_size}Mb on ${total_source_files_size}Mb."
	echo "Processing en: $(date +%D\ at\ %Hh%Mm) - Duration: ${time_formated}."
	echo
fi
}
# Remove source files
remove_source_files() {
if [ "${#lst_audio_opus_encoded[@]}" -gt 0 ] ; then
	read -r -p "Remove source files? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			# Remove source files
			for file in "${lst_audio_src_pass[@]}"; do
				rm -f "$file" 2>/dev/null
			done
		;;
		*)
			source_not_removed="1"
		;;
	esac
fi
}
# Remove target files
remove_target_files() {
if [ "$source_not_removed" = "1" ] ; then
	read -r -p "Remove target files? [y/N]:" qarm
	case $qarm in
		"Y"|"y")
			# Remove source files
			for file in "${lst_audio_opus_encoded[@]}"; do
				rm -f "$file" 2>/dev/null
			done
		;;
	esac
fi
}
# Test dependencies
command_label() {
if [[ "$command" = "ffprobe" ]]; then
	command="$command (ffmpeg package)"
fi
if [[ "$command" = "mutagen-inspect" ]]; then
	command="$command (python3-mutagen package)"
fi
}
command_display() {
local label
label="$1"
if (( "${#command_fail[@]}" )); then
	echo
	echo "Please install the $label dependencies:"
	display_list_truncate "${command_fail[@]}"
	echo
	exit
fi
}
command_test() {
n=0;
for command in "${core_dependencies[@]}"; do
	if hash "$command" &>/dev/null; then
		(( c++ )) || true
	else
		command_label
		command_fail+=("[!] $command")
		(( n++ )) || true
	fi
done
command_display "2opus"
}
# Cache
cache() {
# Check cache directory
if [ ! -d "$cache_dir" ]; then
	mkdir "$cache_dir"
fi

# Consider if file exist in cache directory after 1 days, delete it
find "$cache_dir/" -type f -mtime +1 -exec /bin/rm -f {} \;
}
# Usage print
usage() {
cat <<- EOF
2opus - GNU GPL-2.0 Copyright - <https://github.com/Jocker666z/2opus>
Various lossless to OPUS while keeping the tags.

Processes all compatible files in the current directory
and his three subdirectories.

Usage:
2opus [options]

Options:
  --ape_only              Encode only Monkey's Audio source.
  --dsd_only              Encode only DSD source.
  --flac_only             Encode only FLAC source.
  --m4a_only              Encode only M4A source.
  --mp3_only              Encode only MP3 source.
  --wav_only              Encode only WAV source.
  --wavpack_only          Encode only WAVPACK source.
  -v, --verbose           More verbose, for debug.

Supported source files:
  * AAC ALAC as .m4a
  * DSD as .dsf
  * FLAC as .flac
  * MP3 as .mp3
  * WAV as .wav
  * WAVPACK as .wv
EOF
}

# Need Dependencies
core_dependencies=(ffmpeg ffprobe mutagen-inspect opusenc opustags)
# Paths
export PATH=$PATH:/home/$USER/.local/bin
cache_dir="/tmp/2opus"
# Nb process parrallel (nb of processor)
nproc=$(grep -cE 'processor' /proc/cpuinfo)
# Input extention available
input_ext="ape|dsf|flac|m4a|mp3|ogg|wv|wav"
# FFMPEG
ffmpeg_log_lvl="-hide_banner -loglevel panic -nostats"
# OPUS
opus_bitrate="192"
opus_version=$(opusenc -V | head -1 | awk -F"[()]" '{print $2}' | cut -d' ' -f2-)
# Tag whitelist according with:
# https://picard-docs.musicbrainz.org/en/appendices/tag_mapping.html
# Ommit: ENCODEDBY, ENCODERSETTINGS
Vorbis_whitelist=(
	'ACOUSTID_ID'
	'ACOUSTID_FINGERPRINT'
	'ALBUM'
	'ALBUMARTIST'
	'ALBUMARTISTSORT'
	'ALBUMSORT'
	'ARRANGER'
	'ARTIST'
	'ARTISTSORT'
	'ARTISTS'
	'ASIN'
	'BARCODE'
	'BPM'
	'CATALOGNUMBER'
	'COMMENT'
	'COMPILATION'
	'COMPOSER'
	'COMPOSERSORT'
	'CONDUCTOR'
	'COPYRIGHT'
	'DIRECTOR'
	'DISCNUMBER'
	'DISCSUBTITLE'
	'ENGINEER'
	'GENRE'
	'GROUPING'
	'KEY'
	'ISRC'
	'LANGUAGE'
	'LICENSE'
	'LYRICIST'
	'LYRICS'
	'MEDIA'
	'DJMIXER'
	'MIXER'
	'MOOD'
	'MOVEMENTNAME'
	'MOVEMENTTOTAL'
	'MOVEMENT'
	'MUSICBRAINZ_ARTISTID'
	'MUSICBRAINZ_DISCID'
	'MUSICBRAINZ_ORIGINALARTISTID'
	'MUSICBRAINZ_ORIGINALALBUMID'
	'MUSICBRAINZ_TRACKID'
	'MUSICBRAINZ_ALBUMARTISTID'
	'MUSICBRAINZ_RELEASEGROUPID'
	'MUSICBRAINZ_ALBUMID'
	'MUSICBRAINZ_RELEASETRACKID'
	'MUSICBRAINZ_TRMID'
	'MUSICBRAINZ_WORKID'
	'MUSICIP_PUID'
	'ORIGINALFILENAME'
	'ORIGINALDATE'
	'ORIGINALYEAR'
	'PERFORMER'
	'PRODUCER'
	'RATING'
	'LABEL'
	'RELEASECOUNTRY'
	'DATE'
	'RELEASESTATUS'
	'RELEASETYPE'
	'REMIXER'
	'REPLAYGAIN_ALBUM_GAIN'
	'REPLAYGAIN_ALBUM_PEAK'
	'REPLAYGAIN_ALBUM_RANGE'
	'REPLAYGAIN_REFERENCE_LOUDNESS'
	'REPLAYGAIN_TRACK_GAIN'
	'REPLAYGAIN_TRACK_PEAK'
	'REPLAYGAIN_TRACK_RANGE'
	'SCRIPT'
	'SHOWMOVEMENT'
	'SUBTITLE'
	'TOTALDISCS'
	'DISCTOTAL'
	'TRACKTOTAL'
	'TOTALTRACKS'
	'TRACKNUMBER'
	'TITLE'
	'TITLESORT'
	'WEBSITE'
	'WORK'
	'WRITER'
)

# Command arguments
while [[ $# -gt 0 ]]; do
	key="$1"
	case "$key" in
	-h|--help)
		usage
		exit
	;;
	"--ape_only")
		ape_only="1"
	;;
	"--dsd_only")
		dsd_only="1"
	;;
	"--flac_only")
		flac_only="1"
	;;
	"--M4A_only")
		M4A_only="1"
	;;
	"--MP3_only")
		MP3_only="1"
	;;
	"--wav_only")
		wav_only="1"
	;;
	"--wavpack_only")
		wavpack_only="1"
	;;
	-v|--verbose)
		verbose="1"
	;;
	*)
		usage
		exit
	;;
esac
shift
done

# Cache test
cache

# Test dependencies
command_test

# Find source files
search_source_files

# Start main
if (( "${#lst_audio_src[@]}" )); then
	echo
	echo "2opus start processing with $opus_version \(^o^)/"
	echo "Working directory: $(echo ${PWD} | rev | cut -d'/' -f-1 | rev)"
	echo
	echo "${#lst_audio_src[@]} source files found"

	# Test
	test_source

	# Decode
	decode_source

	# Encode
	encode_opus

	# Tag
	tags_2_opus
	tag_opus

	# End
	summary_of_processing
	if (( "${#lst_audio_opus_encoded[@]}" )); then
		remove_source_files
		remove_target_files
	fi
fi
exit
