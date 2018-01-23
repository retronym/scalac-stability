#!/usr/bin/env bash
set -e
argsfile=${1/@/}
workingdir=$2
SCALAC=${SCALAC:-scalac}
declare -a allsources
mkdir -p $workingdir

refout=$workingdir/reference
recompileout=$workingdir/recompile
mkdir -p $refout
mkdir -p $recompileout
recompileargsfile=$workingdir/recompileargsfile

# Write a copy of the args file without `-cp\n...` and without source files
rm -rf $recompileargsfile
touch $recompileargsfile
for line in $(cat $argsfile); do
    case $line in
    *.scala)
        allsources+=($line)
        ;;    
    *.java)
        allsources+=($line)
        ;;
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

echo "Compiling with sources in given order"
"$SCALAC" -J-Xmx1G @$argsfile -d $refout

# Create an argument file with sources in reverse order
sourcesfile=$workingdir/sourcesfile
rm -rf $sourcesfile
touch $sourcesfile
for ((i=${#allsources[@]}-1; i>=0; i--)); do
  echo "${allsources[$i]}" >> $sourcesfile
done

echo "Recompiling with sources in reverse order"
"$SCALAC" -J-Xmx1G @$recompileargsfile -d $recompileout @$sourcesfile
jardiff -r $refout $recompileout  | head -n 1000

for ((i=${#allsources[@]}-1; i>=0; i--)); do
  file="${allsources[i]}"
  echo "Individually compiling $file"
  "$SCALAC" -nobootcp -Dscala.usejavacp=false @$recompileargsfile -cp $recompileout:${classpath:-dummy} -d $recompileout $file
  jardiff -r $refout $recompileout | head -n 1000
done
