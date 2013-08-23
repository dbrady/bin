#!/bin/bash
if git checkout $* 2>/dev/null; then
  exit 0
else
  if [ "x" = "x$(git branch | grep $1 | sed -e 's/\*//' | awk '{ print $1 }')" ]; then
    echo Could not find a matching branch: $1
    exit 1
  else
    git checkout $(git branch | grep $1 | sed -e 's/\*//' | awk '{ print $1 }')
  fi
fi
