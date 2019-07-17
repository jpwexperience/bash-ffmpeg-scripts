#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
	echo "Usage: $(basename $0) [-i video input file] [-o output path] [-s start time] [-t duration] [-v subtitle type] [-c subtitle stream choice] [-w crop width] [-h crop height] [-l scale width] [-f fps value] [-r crf value]" >&2
	exit 0
fi

while getopts i:o:s:t:v:c:w:h:l:f:r: opt; do
  case $opt in
    i)
      fileIn="$OPTARG" #Video input file
      echo "-i was triggered, Parameter: $OPTARG" >&2
      ;;
    o)
      outGif="$OPTARG" #path and name of output gif
      echo "-o was triggered, Parameter: $OPTARG" >&2
      ;;
    s)
      clipStart="$OPTARG" #start time
      echo "-s was triggered, Parameter: $OPTARG" >&2
      ;;
    t)
      echo "-t was triggered, Parameter: $OPTARG" >&2
      dur="$OPTARG" #clip duration
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
      scaleFactor="$OPTARG" #width of how much you want to scale video by. width:-1
      echo "-l was triggered, Parameter: $OPTARG" >&2
      ;;
    f)
      fpsValue="$OPTARG" #fps of gif
      echo "-f was triggered, Parameter: $OPTION"
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
    ?)
      echo "Usage: $(basename $0) [-i video input file] [-o output path] [-s start time] [-t duration] [-v subtitle type] [-c subtitle stream choice] [-w crop width] [-h crop height] [-l scale width] [-f fps value] [-r crf value]" >&2
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"
subArr=()
subtitleCmd=""
fastSub=0
tempCut=""


if [[ ! -e $fileIn ]]; then
	echo "$fileIn is not a file"
	exit 1
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
        subChoice="n"
fi
if [[ -z "$scaleFactor" ]]; then
        scaleFactor="-1"
fi
if [[ -z "$fpsValue" ]]; then
        fpsValue="23"
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

temp="$name-temp-clip"
tempClip="$dir$temp.mp4"

pal="$name-togif-palette"
gifPal="gif-palette"
palettePath="$dir$pal.png"
outPath="$outGif"

if [ -z "$outGif" ]; then
	outPath="$dir$name-togif.gif"
else
	gifBase=${outGif##*/}
	gifDir=${outGif%$gifBase}
	outPath="$outGif"
	palettePath="$dir$pal.png"
fi

if [ -z "$clipStart" ]; then
	clipStart=0
fi

if [ -z "$dur" ]; then
	dur=5
fi

if [ -z "$crf" ]; then
	crf=26
fi

if [ -z "$fpsValue" ]; then
	fpsValue="10"
fi

if [ -z "$scaleFactor" ]; then
	palette="-vf fps=$fpsValue,scale=-1:-1:flags=lanczos,palettegen \"$palettePath\""
	gifPalette="-filter_complex \"fps=$fpsValue,scale=-1:-1:flags=lanczos[x];[x][1:v]paletteuse\" \"$outPath\""
else
	palette="-vf fps=$fpsValue,scale=$scaleFactor:-1:flags=lanczos,palettegen \"$palettePath\""
	gifPalette="-filter_complex \"fps=$fpsValue,scale=$scaleFactor:-1:flags=lanczos[x];[x][1:v]paletteuse\" \"$outPath\""
fi

ffStart="ffmpeg -analyzeduration 100M -probesize 500k -hide_banner -y"
ffCrop="-vf \"crop=$cropW:$cropH, scale=$scaleFactor:-1\""

if [[ "$subType" == "n" ]]; then
	if [[ "$cropW" == "-1" ]]; then
		tempCut="$ffStart -ss $clipStart -i \"$fileIn\" -t $dur -map 0:v:0 -vf \"scale=$scaleFactor:-1\" -c:v libx264 -an -crf $crf \"$tempClip\""
	else
		tempCut="$ffStart -ss $clipStart -i \"$fileIn\" -t $dur -map 0:v:0 $ffCrop -c:v libx264 -an -crf $crf \"$tempClip\""
	fi
else
	if [[ "$subType" == "i" ]]; then
		if (( $fastSub == 1)); then
			tempCut="$ffStart -ss $clipStart -i \"$fileIn\" -t $dur $subtitleCmd"
			tempCut="$tempCut -an -crf $crf \"$tempClip\""
		else
			tempCut="$ffStart -i \"$fileIn\" -map 0:v:0 -ss $clipStart -t $dur $subtitleCmd"
			tempCut="$tempCut -c:v libx264 -an -crf $crf \"$tempClip\""
		fi
	else
		tempCut="$ffStart -i \"$fileIn\" -map 0:v:0 -ss $clipStart -t $dur $subtitleCmd"
		tempCut="$tempCut -c:v libx264 -an -crf $crf \"$tempClip\""
	fi
fi


echo -e "\nGenerating Clip\n$tempCut\n"
eval $tempCut

ffBegin="ffmpeg -analyzeduration 100M -probesize 500k -hide_banner -y -i \"$tempClip\""
paletteGen="$ffBegin $palette"
echo -e "Generating Palette\n$paletteGen\n"
eval $paletteGen

gifCreate="$ffBegin -i \"$palettePath\" $gifPalette"
echo -e "Creating Gif\n$gifCreate\n"
eval $gifCreate

clipRm="rm \"$tempClip\""
echo -e "Removing Temporary Clip\n$clipRm\n"
eval $clipRm

palRm="rm \"$palettePath\""
echo -e "Removing Palette\n$palRm\n"
eval $palRm
