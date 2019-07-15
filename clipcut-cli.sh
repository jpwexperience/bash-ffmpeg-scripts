#!/usr/bin/env bash
#Does accept multiple inputs but they are run sequentially
#total streams
streamArr=()

videoArr=()
videoMetaArr=()
videoTypeArr=()
videoChoice=0 #user input video stream choice

audioArr=()
audioMetaArr=()
audioTypeArr=()
audioChoice=0 #user input subtitle stream choice

subtitleArr=()	
subtitleTypeArr=()
subtitleMetaArr=()
subtitleChoice=0 #user input subtitle stream choice

ffprobeOut=() #ffprobe output array. each element is the next line
verboseFl=0 #full ffprobe output

inputSize=0 #number of ffprobe output lines 
cmd=""

#$1: User Input 
#$2: Number of Streams
inRangeCode=0
in_range () {
	compare=$(($2-1))
	#echo "$1 and $compare"
	#Check if input is a number
	if (( $1 > $compare )) || (( $1 < -1)) || (( $1 == -1)); then
		inRangeCode=-1
	else
		if ! [[ $1 =~ ^[+-]?[0-9]+([.][0-9]+)?$ ]]; then
			echo "Number not entered. Default to -1"
			inRangeCode=-1
		else
			inRangeCode=$1
		fi
	fi
	#echo "$inRangeCode"
}

#$1: index number
#$2: total number of lines
#$3: type
meta_check () {
	total=$(($2-1))
	index=$(($1+1))
	sType=$3
	entry="null"
	if (( $index >= $total )); then
		#echo "no available meta"
		:
	else
		#echo "${ffprobeOut[$index]}"	
		if [[ ${ffprobeOut[$index]} =~ (.*)(M|m)"etadata"(.*) ]]; then
			index=$((index+1))
			if [[ ${ffprobeOut[$index]} =~ (.*)(T|t)"itle"(.*) ]]; then
				entry="${ffprobeOut[$index]}"
				#echo "$entry"
			fi
		fi
	fi
	if [[ $sType == "audio" ]]; then
		#echo "$entry -$sType-"
		audioMetaArr+=("$entry")
	elif [[ $sType == "subtitle" ]]; then
		#echo "$entry -$sType-"
		subtitleMetaArr+=("$entry")
	else [[ $sType == "video" ]]
		#echo "$entry -$sType-"
		videoMetaArr+=("$entry")
	fi
}

#set flags for input
for flag in "$@"; do
	if [[ $flag == "-v" ]]; then
		verboseFl=1
	fi
done
#loop through command line arguments
for input in "$@"; do
	#Loop to continue cutting clips if desired
	mainLoop=1
	while (( $mainLoop == 1 )); do
		#currently only check if extra arguments are files
		if [[ -e $input && $input != "-v" ]]; then 
			streamArr=()
			videoArr=()
			videoMetaArr=()
			videoTypeArr=()
			audioArr=()
			audioMetaArr=()
			audioTypeArr=()
			subtitleArr=()	
			subtitleTypeArr=()
			subtitleMetaArr=()
			base=${input##*/}
			temp=${base%.*}
			dir=${input%$base}
			#will likely be changing containers
			base="$temp"
			#running into problems where the name has '.' in it
			ext=${input##*.}
			echo -e "\nbase: $base dir: $dir ext: $ext"
			#get file information, redirect sterr
			info="$(ffprobe -analyzeduration 100M -probesize 500K -i "$input" -hide_banner 2>&1)"
			if (( verboseFl == 1 )); then
				echo "$input"
			fi
			#echo -e "\n${#info[@]}"
			IFS='\n' read -ra ADDR <<< "$info"
			ffprobeOut=()
			ffprobeOutSize=${#ffprobeOut[@]}
			#read each line of ffprobe output
			#for line in "${ffprobeOut[@]}"; do
			while read -r line; do
				ffprobeOut+=("$line")
			done <<< "$info"
			outLen=${#ffprobeOut[@]}
			for ((i = 0; i < $outLen; i++)); do
				if (( verboseFl == 1 )); then
					echo "${ffprobeOut[i]}"
				fi
				line=${ffprobeOut[i]}

				if [[ $line =~ (S|s)"tream"(.*) ]]; then
					#echo "$line"	
					streamArr+=("$line")
					if [[ $line =~ (.*)(V|v)"ideo"(.*) ]]; then
						videoArr+=("$line")
						meta_check $i $outLen "video"
						#this is causing issues if no metadata is available
						#Possibly skips next stream
					elif [[ $line =~ (.*)(A|a)"udio"(.*) ]]; then
						audioArr+=("$line")
						meta_check $i $outLen "audio"
					elif [[ $line =~ (.*)(: )(S|s)"ubtitle"(.*) ]]; then
						subtitleArr+=("$line")
						subtitleTypeArr+=("internal")
						meta_check $i $outLen "subtitle"
					else
						#echo "$line"
						#echo "Unidentified Stream"
						:
					fi	

				fi
			done
			for sub in ls "$dir"*; do
				subExt=${sub##*.}
				#echo "$subExt"
				if [[ $subExt =~ (srt|ass) ]]; then
					subtitleArr+=("$sub")
					subtitleTypeArr+=("$subExt")
				fi
			done
			#print out all streams

			echo -e "\n\t--- Streams ---"
			echo "Number of video streams: ${#videoArr[@]} | Number of audio streams: ${#audioArr[@]} | Number of subtitle streams: ${#subtitleArr[@]}"
			#yooo=0
			#echo -e "\n${ffprobeOut[yooo]}"
			#echo -e "\n\n---------------------------------"
			#echo "number of stream pieces: $temp"
			#for i in ${streamArr[@]}; do
				#
			#done
			videoChoice=0
			if (( ${#videoArr[@]} == 0 )); then
				echo "No Video Tracks"
				videoChoice=-1
			elif (( ${#videoArr[@]} == 1 )); then
				#echo "Default to Single Video Stream"
				videoChoice=0
				#echo "${videoArr[videoChoice]}"
			else
				count=0
				echo -e "\n\t-Video Streams-"
				#for i in "${videoArr[@]}"; do
				for ((in = 0; in < ${#videoArr[@]}; in++)); do
					i=${videoArr[in]}
					met=${videoMetaArr[0]}
					firstChunk=${i%%,*}
					mainContent=${firstChunk##*:\ }
					#echo "$firstChunk"
					echo "$count) | $firstChunk"
					mainMetaContent=${met#*:\ }
					if [[ $met == "null" ]]; then
						mainMetaContent=""
					fi
					echo -e "$mainMetaContent\n"
					type=${mainContent##*:}
					type=${mainContent##*:}
					type=${type#\ }
					type=${type%%\ *}
					#echo "$type"
					videoTypeArr+=("$type")
					count=$((count+1))
				done
				read -p "Type the number corresponding to the video stream you want to use, followed by [ENTER]: " videoChoice
				in_range $videoChoice ${#videoArr[@]} 
				#echo "$inRangeCode"
				videoChoice=$inRangeCode
			fi
			audioChoice=0
			if (( ${#audioArr[@]} == 0 )); then
				echo "No Audio Choice"
				audioChoice=-1
			else	
				count=0
				echo -e "\n\t-Audio Streams-"
				#for i in $(seq 1 ${#audioArr[@]}); do
				#	echo $i
				#done
				for ((in = 0; in < ${#audioArr[@]}; in++)); do
					i=${audioArr[in]}
					met=${audioMetaArr[in]}
				#for i in "${audioArr[@]}"; do
					firstChunk=${i%%,*}
					mainContent=${firstChunk##*:\ }
					#echo "$firstChunk"
					echo "$count) | $firstChunk"
					mainMetaContent=${met#*:\ }
					if [[ $met == "null" ]]; then
						mainMetaContent=""
					fi
					echo -e "$mainMetaContent\n"
					type=${mainContent##*:}
					type=${type#\ }
					type=${type%%\ *}
					#echo "$type"
					audioTypeArr+=("$type")
					count=$((count+1))
				#done			
				done
				
				read -p "Type the number corresponding to the audio stream you want to use (-1 for no audio), followed by [ENTER]: " audioChoice
				in_range $audioChoice ${#audioArr[@]} 
				#echo "$inRangeCode"
				#echo "$audioChoice"
				audioChoice=$inRangeCode
			fi
			subtitleChoice=0
			if (( ${#subtitleArr[@]} == 0 )); then
				echo "No Subtitle Streams"
				subtitleChoice=-1
				#echo "$subtitleChoice"
			else
				count=0
				echo -e "\n\t-Subtitle Streams-"
				#for i in "${subtitleArr[@]}"; do
				for ((in = 0; in < ${#subtitleArr[@]}; in++)); do
					i=${subtitleArr[in]}
					met=${subtitleMetaArr[in]}
					firstChunk=${i%%,*}
					mainContent=${firstChunk##*:\ }
					#echo "$firstChunk"
					echo "$count) | $firstChunk"
					mainMetaContent=${met#*:\ }
					if [[ $met == "null" ]]; then
						mainMetaContent=""
					fi
					echo -e "$mainMetaContent\n"
					type=${mainContent##*:}
					type=${mainContent##*:}
					type=${type#\ }
					type=${type%%\ *}
					#echo "$type"
					if [[ ${subtitleTypeArr} == "internal" ]]; then
						subtitleTypeArr[in]="$type"
					fi
					count=$((count+1))
				done
				read -p "Type the number corresponding to the subtitle stream you want to use (-1 for no subtitles), followed by [ENTER]: " subtitleChoice
				in_range $subtitleChoice ${#subtitleArr[@]} 
				subtitleChoice=$inRangeCode
			fi
		#Skip argument if it isnt a file
		else
			if [[ $input != "-v" ]]; then
				echo "$i is not a file"
				exit 1
			fi
		fi
		echo -e "\n=========="
		echo -e "\nVideo Choice: $videoChoice Audio Choice: $audioChoice Subtitle Choice: $subtitleChoice"
		read -p "Enter Clip Start Time: " clipStart
		#echo "$clipStart"
		read -p "Enter Clip Duration in Seconds: " clipDur
		#echo "$clipEnd"
		echo -e "Enter CRF Quality Level | Lower Value is Higher Quality\n18-32 is typical range, if burning subtitles may want to use a value around 10"
		read -p "Use -1 for no re-encoding: "  crfIn
		read -p "Enter output path with extension | .mkv, .mp4, or .mov is preferred: " outputPath
		cmd="ffmpeg -analyzeduration 100M -probesize 500K -hide_banner"
		cmdIn="-i \"$dir$base.$ext\""
		cmdStart="-ss $clipStart"
		cmdDur="-t $clipDur"
		cmdCrf="-crf $crfIn"
		cmdOut="\"$outputPath\""
		cmdFiltComp="-filter_complex \"[0:v:$videoChoice][0:s:$subtitleChoice]overlay[v]\" -map \"[v]\""
		cmdMapV="-map 0:v:$videoChoice" 
		cmdMapA="-map 0:a:$audioChoice"
		cmdAudio="-c:a aac"
		cmdVfInt="-vf subtitles=\"$dir$base.$ext:si=$subtitleChoice\""
		cmdVfExt="-vf subtitles=\"$subCmd\""
		if (( $subtitleChoice >= 0 )); then
			#echo "Burn subs"
			subCmd="${subtitleArr[subtitleChoice]}"
			subCmdType="${subtitleTypeArr[subtitleChoice]}"
			echo "$subCmdType"
			if (( $crfIn == -1 )); then
				crfIn=18
			fi
			if [[ $subCmd =~ (.*)(hdmv|dvd_subtitle)(.*) ]]; then
				echo "Fast Burn"
				if (( $audioChoice == -1 )); then
					cmd="$cmd $cmdStart $cmdIn $cmdDur $cmdFiltComp $cmdAudio -an $cmdCrf $cmdOut"
				else
					cmd="$cmd $cmdStart $cmdIn $cmdDur $cmdFiltComp $cmdMapA $cmdAudio $cmdCrf $cmdOut"
				fi
			elif [[ $subCmdType =~ (srt|ass) ]]; then
				echo "Slow Burn - External"
				if (( $audioChoice == -1 )); then
					cmd="$cmd $cmdIn $cmdStart $cmdDur $cmdVfExt -an $cmdCrf $cmdOut"
				else
					cmd="$cmd $cmdIn $cmdMapV $cmdMapA $cmdStart $cmdDur $cmdVfExt $cmdAudio $cmdCrf $cmdOut"
				fi
			else
				echo "Slow Burn - Internal"
				if (( $audioChoice == -1 )); then
					cmd="$cmd $cmdIn $cmdStart $cmdDur $cmdVfInt -an $cmdCrf $cmdOut"
				else
					cmd="$cmd $cmdIn $cmdMapV $cmdMapA $cmdStart $cmdDur $cmdVfInt $cmdAudio $cmdCrf $cmdOut"
				fi

			fi
		else
			echo "No Subs"
			if (( crfIn == -1 )); then
				cmd="$cmd $cmdStart $cmdIn $cmdDur -c copy $cmdOut"
			else
				if (( $audioChoice == -1 )); then
					cmd="$cmd $cmdStart $cmdIn $cmdStart -an $cmdCrf $cmdOut"
				else
					cmd="$cmd $cmdStart $cmdIn $cmdDur $cmdMapV $cmdMapA $cmdAudio $cmdCrf $cmdOut"
				fi
			fi
		fi
		echo -e "\n$cmd\n"
		eval $cmd
		nextLoop=1
		while (( $nextLoop == 1 )); do
			echo -e "\n0) Make Another Clip\n1) Continue to Next Input\n2) Play Clip\n3) Exit"
			read -p "Type the number corresponding to what you want to do next: " nextStep
			if (( $nextStep == 0 )); then
				nextLoop=0
			elif (( $nextStep == 1 )); then
				nextLoop=0
				mainLoop=0
			elif (( $nextStep == 2 )); then
				eval "ffplay -i \"$dir$outputPath\""
			elif (( $nextStep == 3 )); then
				echo "Exiting"
				exit 0
			else
				echo "Unrecognized Option. Exiting"
				exit 0
			fi
		done
	done
done
exit 0
