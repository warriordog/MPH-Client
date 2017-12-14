#!/bin/bash
# Bash script to check ruby source for errors

# File pattern to search for
pattern="*.rb"

# Directory to search in
dir="../src"

# Read arguments    
if [ $# -gt 0 ]; then
    dir=$1
fi
if [ $# -gt 1 ]; then
    pattern=$2
fi

# Find files
for fl in $dir/$pattern; do
    echo -n "Checking $fl: "
    
    # Run ruby check
    output=$(ruby -c -w $fl 2>&1)
    
    # compare output
    if [ "$output" == "Syntax OK" ]; then
        echo "OK"
    else
        echo "failed!"
        echo "$output"
        exit 1
    fi
done

echo "Everything OK"
