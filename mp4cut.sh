#!/usr/bin/env bash
#Cut a clip given input, start point, and duration

if [ "$#" -eq 0 ]; then
  echo "Usage: $(basename $0) [-i video input file] [-o output path] [-s start time] [-t duration] [-v subtitle type] [-c subtitle stream choice] [-w crop width] [-h crop height] [-l scale width] [-r crf value] [-a no audio]" >&2
  exit 0
fi

while getopts i:o:s:t:v:c:w:h:l:f:r:a opt; do
  case $opt in
    i)
      fileIn="$OPTARG"
      echo "-i was triggered, Parameter: $OPTARG" >&2
      ;;
    o)
      outVid="$OPTARG" #path and name of output gif
      echo "-o was triggered, Parameter: $OPTARG" >&2
      ;;
    s)
      clipStart="$OPTARG" #start time
      echo "-s was triggered, Parameter: $OPTARG" >&2
      ;;
    t)
      dur="$OPTARG" #clip duration
      echo "-t was triggered, Parameter: $OPTARG" >&2
      ;;
    v)
      subType="$OPTARG" #e or i for external and interal respectively
      echo "-v was triggered, Parameter: $OPTARG" >&2
      ;;
    c)
      subChoice="$OPTARG"
      echo "-c was triggered, Parameter: $OPTARG" >&2
      ;;
    r)
      crf="$OPTARG" #quality level
      echo "-r was triggered, Parameter: $OPTARG" >&2
      ;;
    w)
      cropW="$OPTARG"
      echo "-w was triggered, Parameter: $OPTARG" >&2
      ;;
    h)
      cropH="$OPTARG"
      echo "-h was triggered, Parameter: $OPTARG" >&2
      ;;
    l)
      scale="$OPTARG" #width of how much you want to scale video by. width:-1
      echo "-l was triggered, Parameter: $OPTARG" >&2
      ;;
    r)
      crf="$OPTARG" #width of how much you want to scale video by. width:-1
      echo "-l was triggered, Parameter: $OPTARG" >&2
      ;;
    a)
      audio="an" #fps of gif
      echo "-a was triggered, Parameter: $OPTION"
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    ?)
      echo "Usage: $(basename $0) [-i video input file] [-o output path] [-s start time] [-t duration] [-v subtitle type] [-c subtitle stream choice] [-w crop width] [-h crop height] [-l scale width] [-z video bitrate size in MB] [-r crf value] [-a no audio]" >&2
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"
subArr=()
subtitleCmd=""
fastSub=0

if [[ ! -e $fileIn ]]; then
        echo "That's not a file"
        exit 1
fi

if [[ -z "$cropW" ]]; then
	cropW="-1"
fi
if [[ -z "$cropH" ]]; then
	cropH="-1"
fi
if [[ -z "$scale" ]]; then
	scale="-1"
fi

####Subtitle Stuff
if [[ "$subType" == "i" ]]; then
        if [[ -z "$subChoice" ]]; then
                subChoice="0"
        fi
        info="$(ffprobe -analyzeduration 100M -probesize 500K -i "$fileIn" -hide_banner 2>&1)"
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
                line=${ffprobeOut[i]}
                if [[ $line =~ (S|s)"tream"(.*) ]]; then
                        if [[ $line =~ (.*)(: )(S|s)"ubtitle"(.*) ]]; then
                                subArr+=("$line")
                        fi
                fi
        done
        if (( ${#subArr[@]} > 0 )); then
                subStream=${subArr[subChoice]}
                if [[ $subStream =~ (.*)(hdmv|dvd_subtitle)(.*) ]]; then
			ffMap="-map \"[v]\""
                        fastSub=1
			#need to work out getting the subtitles to crop correctly
			#I think scale will work nicely
			if [[ "$cropW" == "-1" ]]; then
				subtitleCmd="-filter_complex \"[0:v:0][0:s:$subChoice]overlay[s]; [s]scale=$scale:-1[v]\" $ffMap"
			else
				vCrop="[0:v:0]crop=$cropW:$cropH[c]"
				sScale="[0:s:$subChoice]scale=$cropW:$cropH[sub]"
				vsOverlay="[c][sub]overlay[s]"
				vScale="[s]scale=$scale:-1[v]"
				subtitleCmd="-filter_complex \"$vCrop; $sScale; $vsOverlay; $vScale\" $ffMap"
			fi
                else
			if [[ "$cropW" == "-1" ]]; then
				subtitleCmd="-vf \"subtitles=$fileIn:si=$subChoice, scale=$scale:-1\""
			else
				subtitleCmd="-vf \"crop=$cropW:$cropH, subtitles=$fileIn:si=$subChoice, scale=$scale:-1\""
			fi
                fi
        fi
elif [[ "$subType" == "n" ]]; then
	subChoice="n"
else
        if [[ "$subType" == "e" ]]; then
                if [[ -z "$subChoice" ]]; then
                        echo -e "\nNo subtitle path given\n"
                        exit 1
                else
			if [[ "$cropW" == "-1" ]]; then
				subtitleCmd="-vf \"subtitles=$subChoice, scale=$scale:-1\""
			else
				subtitleCmd="-vf \"crop=$cropW:$cropH, subtitles=$subChoice, scale=$scale:-1\""
			fi
                fi

        fi
fi
####

base=${fileIn##*/}
name=${base%.*}
dir=${fileIn%$base}
ext=${base#$name.}

if [ -z "$outVid" ]; then
	outVid="$dir$name-cut.$ext"
fi
if [ -z "$start" ]; then
	start="0"
fi
if [ -z "$dur" ]; then
	dur="10"
fi

ffBeg="ffmpeg -hide_banner -y"
ffStart="-ss $clipStart"
ffIn="-i \"$fileIn\""
ffDur="-t $dur"
ffCrf="-crf $crf"
ffOut="\"$outVid\""
ffVmap="-map 0:v:0"
ffAmap="-map 0:a:0"
ffCv="-c:v libx264"
ffCa="-c:a aac"
ffCrop="-vf \"crop=$cropW:$cropH\""
ffScale="-vf \"scale=$scale:-1\""
ffCropScale="-vf \"crop=$cropW:$cropH, scale=$scale:-1\""

if [[ "$subType" == "n" ]]; then
	if [[ "$cropW" == "-1" ]]; then
		if [[ "$audio" == "an" ]]; then
			if [[ "$scale" == -1 ]]; then
				cutCmd="$ffBeg $ffStart $ffIn $ffDur $ffVmap $ffCv -an $ffCrf $ffOut"
			else
				cutCmd="$ffBeg $ffStart $ffIn $ffDur $ffVmap $ffScale $ffCv -an $ffCrf $ffOut"
			fi
		else
			if [[ "$scale" == -1 ]]; then
				cutCmd="$ffBeg $ffStart $ffIn $ffDur $ffVmap $ffAmap $ffCv $ffCa $ffCrf $ffOut"
			else
				cutCmd="$ffBeg $ffStart $ffIn $ffDur $ffVmap $ffScale $ffAmap $ffCv $ffCa $ffCrf $ffOut"
			fi
		fi
	else
		if [[ "$audio" == "an" ]]; then
			cutCmd="$ffBeg $ffStart $ffIn $ffDur $ffVmap $ffCropScale $ffCv -an $ffCrf $ffOut"
		else
			cutCmd="$ffBeg $ffStart $ffIn $ffDur $ffVmap $ffCropScale $ffCv $ffAmap $ffCa $ffCrf $ffOut"
		fi
	fi
else
        if [[ "$subType" == "i" ]]; then
                if (( $fastSub == 1)); then
                        cutCmd="$ffBeg $ffStart $ffIn $ffDur $subtitleCmd"
			if [[ "$audio" == "an" ]]; then
				cutCmd="$cutCmd -an $ffCrf $ffOut"
			else
				cutCmd="$cutCmd $ffAmap $ffCa $ffCrf $ffOut"
			fi
                else
                        cutCmd="$ffBeg $ffIn $ffVmap $ffStart $ffDur $subtitleCmd"
			if [[ "$audio" == "an" ]]; then
				cutCmd="$cutCmd -an $ffCrf $ffOut"
			else
				cutCmd="$cutCmd $ffAmap $ffCa $ffCrf $ffOut"
			fi
                fi
        else
                cutCmd="$ffBeg $ffIn $ffVmap $ffStart $ffDur $subtitleCmd"
		if [[ "$audio" == "an" ]]; then
			cutCmd="$cutCmd $ffAmap $ffCv -an $ffCrf $ffOut"
		else
			cutCmd="$cutCmd $ffAmap $ffCv $ffCa $ffCrf $ffOut"
		fi
        fi
fi

echo -e "\nGenerating Clip\n$cutCmd\n"
eval $cutCmd
