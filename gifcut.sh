#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
	echo "Usage: $(basename $0) [-i <infile>] [-o <outfile>] [options]" >&2
	echo "For Option List use: $(basename $0) -h" >&2
	exit 1
fi

while getopts i:o:s:t:v:c:w:e:l:f:r:hgk opt; do
  case $opt in
    i)
      fileIn="$OPTARG" #Video input file
      ;;
    o)
      outGif="$OPTARG" #path and name of output gif
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
      scaleFactor="$OPTARG" #width of how much you want to scale video by. width:-1
      ;;
    f)
      fpsValue="$OPTARG" #fps of gif
      ;;
    h)
      HELP="1" #list script options
      ;;
    g)
      noRun="1" #show command only
      ;;
    k)
      keep="1" #show command only
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
tempCut=""

if [ ! -z "$HELP" ]; then
	echo "Usage: $(basename $0) [-i <infile>] [-o <outfile>] [options]"
	echo -e "\nOptions:"
	echo -e "-h\t\t\tList available options"
	echo -e "-g\t\t\tOnly show generated commands"
	echo -e "-k\t\t\tKeep temporary clips"
	echo -e "-s start\t\tClip start time in seconds or timecode (00:00:00.00) [default: 0]"
	echo -e "-t duration\t\tClip duration time in seconds or timecode (00:00:00.00) [default: 10]"
	echo -e "-v ( i | e )\t\tVideo subtitle type. Internal (i) or External (e)"
	echo -e "-c subchoice\t\tVideo subtitle stream choice or path to external subtitle file"
	echo -e "-w width\t\tWidth cropping in pixels"
	echo -e "-e height\t\tHeight cropping in pixels"
	echo -e "-l scale\t\tWidth to scale video by in pixels"
	echo -e "-r crf\t\t\tQuality level for x264 encoding. Lower # = Higher Quality. 18-32 is sane range [default: 10]"
	echo -e "-f fps\t\t\tFrames per second of final gif [default: 23]"
	exit 0
fi

if [ -z "$noRun" ]; then
	noRun="0"
fi

if [[ ! -e $fileIn ]]; then
	echo "$fileIn is not a file" >&2
	echo "Usage: $(basename $0) [-i <infile>] [-o <outfile>] [options]" >&2
	exit 1
fi

if [ -z "$outGif" ]; then
	echo "No output file. Use [-o <output filepath>]"
  exit 1
else
	outExt=${outGif##?*.}
fi

if [ -z "$clipStart" ]; then
	clipStart=0
fi

if [ -z "$dur" ]; then
	dur=5
fi

if [ -z "$crf" ]; then
	crf=10
fi

if [ -z "$fpsValue" ]; then
	fpsValue="10"
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
if [[ -z "$keep" ]]; then
        keep="0"
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

temp="$name-temp-clip"
tempClip="$dir$temp.mp4"

pal="$name-togif-palette"
gifPal="gif-palette"
palettePath="$dir$pal.png"
outPath="$outGif"

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


if [[ "$noRun" == 0 ]]; then
	echo -e "\nGenerating Clip\n$tempCut\n"
	eval $tempCut

	ffBegin="ffmpeg -analyzeduration 100M -probesize 500k -hide_banner -y -i \"$tempClip\""
	paletteGen="$ffBegin $palette"
	echo -e "Generating Palette\n$paletteGen\n"
	eval $paletteGen

	gifCreate="$ffBegin -i \"$palettePath\" $gifPalette"
	echo -e "Creating Gif\n$gifCreate\n"
	eval $gifCreate

	if [[ "$keep" == 0 ]]; then
		clipRm="rm \"$tempClip\""
		echo -e "Removing Temporary Clip\n$clipRm\n"
		eval $clipRm

		palRm="rm \"$palettePath\""
		echo -e "Removing Palette\n$palRm\n"
		eval $palRm
	fi
else
	echo -e "\nGenerating Clip\n$tempCut\n"
	ffBegin="ffmpeg -analyzeduration 100M -probesize 500k -hide_banner -y -i \"$tempClip\""
	paletteGen="$ffBegin $palette"
	echo -e "Generating Palette\n$paletteGen\n"

	gifCreate="$ffBegin -i \"$palettePath\" $gifPalette"
	echo -e "Creating Gif\n$gifCreate\n"

	clipRm="rm \"$tempClip\""
	echo -e "Removing Temporary Clip\n$clipRm\n"

	palRm="rm \"$palettePath\""
	echo -e "Removing Palette\n$palRm\n"
fi
