#!/usr/bin/env bash
set -e
argsfile=$1
sourcesfile=$2
workingdir=$3
SCALAC=${SCALAC:-scalac}
declare -a allsources
readarray -t allsources < $sourcesfile # Exclude newline.
mkdir -p $workingdir

refout=$workingdir/reference
recompileout=$workingdir/recompile
mkdir -p $refout
mkdir -p $recompileout
recompileargsfile=$workingdir/recompileargsfile

echo "Compiling with sources in given order"
"$SCALAC" @$argsfile -d $refout @$sourcesfile

# Create file with sources files in reverse order
sourcesfile1=$workingdir/sourcesfile
rm -rf $sourcesfile1
for ((i=${#allsources[@]}-1; i>=0; i--)); do
  echo "${allsources[$i]}" >> $sourcesfile1
done

echo "Recompiling with sources in reverse order"
"$SCALAC" @$argsfile -d $recompileout @$sourcesfile1
jardiff -r $refout $recompileout

# Write a copy of the args file without `-cp\n...`
rm -rf $recompileargsfile
touch $recompileargsfile
for line in $(cat $argsfile); do
    case $line in
    "-classpath")
        iscp=true
        ;;
    "-cp")
        iscp=true
        ;;
    *)        
      if [[ "$iscp" == true ]]; then
        iscp=false
        classpath=$line
      else 
        echo $line > $recompileargsfile
      fi
    esac
done

# Recompile each source file individually
for file in $(cat $sourcesfile); do
  echo "Individually compiling $file"
  "$SCALAC" @$recompileargsfile -cp $recompileout:${classpath:-dummy} -d $recompileout $file
  jardiff -r $refout $recompileout
done
