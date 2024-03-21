#!/bin/bash

if [ $1 == "main" ]; then
    git main
elif [ $1 == "hermes" ]; then
    git hermes
elif [ $1 == "parent" ]; then
    git parent
elif git checkout $@ 2>/dev/null; then
  exit 0
else
  if [ "x" = "x$(git branch | grep $1 | sed -e 's/\*//' | awk '{ print $1 }')" ]; then
    echo Could not find a matching branch: $1
    exit 1
  else
    git checkout $(git branch | grep $1 | sed -e 's/\*//' | awk '{ print $1 }')
  fi
fi
