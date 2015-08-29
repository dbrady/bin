#!/bin/bash
# rg - "rspec go" rus specs focused on a specific subset, set by rf ("rspec focus")
#
# usage:
#
# rg [additional args or focus--will not change focus]

if [ $1 = '-h' ]; then
    rh
    exit 1
fi

echo "Running focused specs"
echo bundle exec rspec $@ $(cat ~/.spec_focus)

bundle exec rspec $@ $(cat ~/.spec_focus)
