#!/usr/bin/env bash
# run a command with SPEC_SEED=true set
#
# Hint: You're going to use this as ss !!
#
# rspec path/to/spec.rb
# # => errors from missing seeds
# ss !!
# # => 'SPEC_SEED=true rspec path/to/spec.rb'

# Print the command in cyan
echo -e "\033[36mSPEC_SEED=true $@\033[0m"

# Execute the command with SPEC_SEED=true
SPEC_SEED=true "$@"
