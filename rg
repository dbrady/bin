#!/bin/bash
# rg - "rspec go" rus specs focused on a specific subset, set by rf ("rspec focus")
#
# usage:
#
# rg [additional args or focus--will not change focus]

if [ "$1" = "-h" ]; then
    rh
    exit 1
fi

echo 'Rspec Focus: Go!'
echo "Running focused specs"
echo time bundle exec rspec $@ $(cat ~/.spec_focus)

time bundle exec rspec $@ $(cat ~/.spec_focus)
