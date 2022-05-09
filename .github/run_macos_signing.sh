#!/bin/bash

echo "======== INPUTS ========"
echo "Directory: $1"
echo "Developer ID: $2"
echo "Entitlements: $3"
echo "======== END INPUTS ========"

cd $1
for f in *
do
    macho=$(file --mime $f | grep mach)
    # Runtime sign dylibs and Mach-O binaries
    if [[ $f == *.dylib ]] || [ ! -z "$macho" ]; 
    then 
        echo "Runtime Signing $f" 
        codesign -s "$2" $f --timestamp --force --options=runtime --entitlements $3
    elif [ -d "$f" ];
    then
        echo "Signing files in subdirectory $f"
        cd $f
        for i in *
        do
            codesign -s "$2" $i --timestamp --force
        done
        cd ..
    else 
        echo "Signing $f"
        codesign -s "$2" $f  --timestamp --force
    fi
done