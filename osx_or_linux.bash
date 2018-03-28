#!/bin/bash
# Example script of how to tell which OS you're using in bash

if [ `uname -s` == "Darwin" ]; then
    echo "OS Detected: Darwin"
elif [ `uname -s` == "Linux" ]; then
    echo "OS Detected: Linux"
fi
