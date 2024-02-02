#!/bin/bash

# Test script for switch and arg syntax

# Declare variables for switches
verbose=false
filename=""

# Define expected options with getopts
while getopts ":vf:" opt; do
  case $opt in
    v)  verbose=true
        echo "Verbose mode enabled." ;;
    f)  filename="$OPTARG"
        echo "Filename set to: $filename" ;;
    \?) echo "Invalid option: -$OPTARG" >&2
        exit 1 ;;
    :)  echo "Option -$OPTARG requires an argument." >&2
        exit 1 ;;
  esac
done

# Shift positional arguments to exclude processed options
shift $((OPTIND-1))

# Access remaining positional arguments (if any)
if [[ $# -gt 0 ]]; then
  echo "Positional arguments:"
  for arg in "$@"; do
    echo "- $arg"
  done
fi

# Use the parsed options and arguments for actions
if $verbose; then
  echo "Doing something in verbose mode..."
fi

if [[ -n $filename ]]; then
  echo "Processing file: $filename"
fi
