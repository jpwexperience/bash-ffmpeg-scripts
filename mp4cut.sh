#!/usr/bin/env bash
#Cut a clip given input, start point, and duration

if [ "$#" -eq 0 ]; then
  echo "Usage: $(basename $0) [-i <infile>] [-o <outfile>] [options]" >&2
  echo "For Option List use: $(basename $0) -h" >&2
  exit 0
fi

while getopts i:o:s:t:v:c:w:e:l:r:ahg opt; do
  case $opt in
    i)
      fileIn="$OPTARG"
      ;;
    o)
      outVid="$OPTARG" #path and name of output gif
      ;;
    s)
      clipStart="$OPTARG" #start time
      ;;
    t)
      dur="$OPTARG" #clip duration
      ;;
    v)
      subType="$OPTARG" #e or i for external and interal respectively
      ;;
    c)
      subChoice="$OPTARG"
      ;;
    r)
      crf="$OPTARG" #quality level
      ;;
    w)
      cropW="$OPTARG"
      ;;
    e)
      cropH="$OPTARG"
      ;;
    l)
      scale="$OPTARG" #width of how much you want to scale video by. width:-1
      ;;
    r)
      crf="$OPTARG" #width of how much you want to scale video by. width:-1
      ;;
    a)
      audio="an" #fps of gif
      ;;
    h)
      HELP="1" #shows options for program
      ;;
    g)
      noRun="1" #shows options for program
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      echo "For Option List use: $(basename $0) -h" >&2
      exit 1
      ;;
    ?)
      echo "Usage: $(basename $0) [-i <infile>] [-o <outfile>] [options]" >&2
      echo "For Option List use: $(basename $0) -h" >&2
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"
subArr=()
subtitleCmd=""
fastSub=0

if [ ! -z "$HELP" ]; then
  echo "Usage: $(basename $0) [-i <infile>] [-o <outfile>] [options]" >&2
  echo -e "\nOptions:"
  echo -e "-h\t\t\tList available options"
  echo -e "-a\t\t\tExclude audio from final clip"
  echo -e "-g\t\t\tOnly show generated commands"
  echo -e "-s start\t\tClip start time in seconds or timecode (00:00:00.00) [default: 0]"
  echo -e "-t duration\t\tClip duration time in seconds or timecode (00:00:00.00) [default: 10]"
  echo -e "-v ( i | e )\t\tVideo subtitle type. Internal (i) or External (e)"
  echo -e "-c subchoice\t\tVideo subtitle stream choice or path to external subtitle file"
  echo -e "-w width\t\tWidth cropping in pixels"
  echo -e "-e height\t\tHeight cropping in pixels"
  echo -e "-l scale\t\tWidth to scale video by in pixels"
  echo -e "-r crf\t\t\tQuality level for x264 encoding. Lower # = Higher Quality. 18-32 is sane range [default: 18]"
  exit 0
fi

if [[ ! -e $fileIn ]]; then
        echo -e "$fileIn is not a file\n" >&2
	echo "Usage: $(basename $0) [-i <infile>] [-o <outfile>] [options]" >&2
        exit 1
fi

if [ -z "$outVid" ]; then
	echo "No output file specified."
	echo "Usage: $(basename $0) [-i <infile>] [-o <outfile>] [options]" >&2
	exit 1
else
  outExt=${outGif##?*.}
  fi

if [ -z "$noRun" ]; then
	noRun="0"
fi

if [ -z "$start" ]; then
	start="0"
fi

if [ -z "$dur" ]; then
	dur="10"
fi

if [[ -z "$cropW" ]]; then
	cropW="-1"
fi

if [[ -z "$cropH" ]]; then
	cropH="-1"
fi

if [[ -z "$subType" ]]; then
	subType="n"
fi

if [[ -z "$subChoice" ]]; then
	subChoice="-1"
fi

if [[ -z "$scale" ]]; then
	scale="-1"
fi

if [[ -z "$crf" ]]; then
	crf="18"
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
		#get source video dimensions
		if [[ $line =~ (.*)(: )(V|v)"ideo"(.*) ]]; then
			# % - suffix
			# # - prefix
			nums=', [0-9]+x[0-9]+'
			if [[ $line =~ $nums ]]; then
				fullDim=${BASH_REMATCH[0]}
				fullDim=${fullDim#', '}
				if [[ "$cropW" == "-1" ]]; then
					cropW=${fullDim%x*}
				fi
				if [[ "$cropH" == "-1" ]]; then
					cropH=${fullDim#*x}
				fi
				if [[ "$scaleFactor" == "-1" ]]; then
					scaleFactor=${fullDim%x*}
				fi
			else
				echo "Can't find video dimensions"
			fi
			echo -e "line: $line\n\nWidth: $cropW Height: $cropH"
		fi
	fi
done

let finalHeight="(($scaleFactor*$cropH)/$cropW)"
#echo -e "\nWidth:$cropW Height: $cropH Scale: $scaleFactor\nFinal Height: $finalHeight"
while (( $finalHeight % 2 == 0 )); do
	echo "Hey bud, $finalHeight % 2 == 0"
	let finalHeight++
	if (( $scaleFactor % 2 == 0 )); then
		let "scaleFactor = $scaleFactor + 2";
	else
		let "scaleFactor = $scaleFactor + 1";
	fi
	let finalHeight=($scaleFactor*$cropH)/$cropW
done

#echo -e "Actual Final\nWidth:$cropW Height: $cropH Scale: $scaleFactor\nFinal Height: $finalHeight"

####Subtitle Stuff
if [[ "$subType" == "i" ]]; then
	if (( ${#subArr[@]} > 0 )); then
		subStream=${subArr[subChoice]}
		if [[ $subStream =~ (.*)(hdmv|dvd_subtitle)(.*) ]]; then
			ffMap="-map \"[v]\""
                        fastSub=1
                        if [[ "$cropW" == "-1" ]]; then
                                subtitleCmd="-filter_complex \"[0:v:0][0:s:$subChoice]overlay[s]; [s]scale=$scaleFactor:-1[v]\" $ffMap"
                        else
				vCrop="[0:v:0]crop=$cropW:$cropH[c]"
				sScale="[0:s:$subChoice]scale=$cropW:$cropH[sub]"
				vsOverlay="[c][sub]overlay[s]"
				vScale="[s]scale=$scaleFactor:-1[v]"
				subtitleCmd="-filter_complex \"$vCrop; $sScale; $vsOverlay; $vScale\" -map \"[v]\""
                        fi
		else
			if [[ "$cropW" == "-1" ]]; then
                                subtitleCmd="-vf \"subtitles=$fileIn:si=$subChoice, scale=$scaleFactor:-1\""
                        else
                                subtitleCmd="-vf \"crop=$cropW:$cropH, subtitles=$fileIn:si=$subChoice, scale=$scaleFactor:-1\""
                        fi
		fi
	fi
else
if [[ "$subType" == "e" ]]; then
	if [[ -z "$subChoice" ]]; then
		echo -e "\nNo subtitle path given\n"
		exit 1
	else
		if [[ "$cropW" == "-1" ]]; then
			subtitleCmd="-vf \"subtitles=$subChoice, scale=$scaleFactor:-1\""
		else
			subtitleCmd="-vf \"crop=$cropW:$cropH, subtitles=$subChoice, scale=$scaleFactor:-1\""
		fi
	fi

fi
fi
####

base=${fileIn##*/}
name=${base%.*}
dir=${fileIn%$base}
ext=${base#$name.}

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

if [[ "$noRun" == "0" ]]; then
	echo -e "\nGenerating Clip\n$cutCmd\n"
	eval $cutCmd
else
	echo -e "\nFFmpeg Command\n$cutCmd\n"
fi
