#!/usr/bin/env ruby
# go - git checkout with matching and helping
require "colorize"
require "optimist"
String.disable_colorization unless $stdout.tty?

opts = Optimist.options do
  banner <<BANNER
go <branch> - git checkout with matching and selecting

If branch matches exactly 1 branch locally, it will switch to that branch. If it
matches multiple, we fire up selecta to choose.
BANNER
  opt :mine, "Assume branches must include my username", default: true
  opt :debug, "Print extra debug info", default: false

end
puts opts.inspect if opts[:debug]

search_term = ARGV * ' '

branches = `git branch -a | grep #{search_term}`.each_line.map(&:strip).to_a

# prune branches - remove remotes/origin/a if we have a in the list.

pruned_branches = branches.find_all { |branch| branch !~ %r|^remotes/origin/| }
pruned_branches = pruned_branches.find_all { |branch| branch =~ /brady/i } if opts[:mine]
# strip off the leading asterisk that marks current branch
pruned_branches = pruned_branches.map { |branch| branch.gsub(/^\* /, '') }

# TODO: This is just a straight port for now, no selecta support yet.

# if branch is an exact match, we're done
exit 0 if system("get checkout '#{search_term}' 2>/dev/null")

# matching branch?
matching_branch = pruned_branches.find { |branch| branch.include? search_term }

if system("git checkout '#{matching_branch}'")
  puts "Switched to #{matching_branch}"
else
  puts "Could not find matching branch"
end

# if system("git checkout '#{search_term}'

  #   if [ "x" = "x$(git branch | grep $1 | sed -e 's/\*//' | awk '{ print $1 }')" ]; then
  #     echo Could not find a matching branch: $1
  #     exit 1
  #   else
  #     git checkout $(git branch | grep $1 | sed -e 's/\*//' | awk '{ print $1 }')
  #   fi
  # fi

# TODO: if git branch -a $@ has more than 1 hit, fire up selecta
# if git checkout $@ 2>/dev/null; then
#   exit 0
# else
#   if [ "x" = "x$(git branch | grep $1 | sed -e 's/\*//' | awk '{ print $1 }')" ]; then
#     echo Could not find a matching branch: $1
#     exit 1
#   else
#     git checkout $(git branch | grep $1 | sed -e 's/\*//' | awk '{ print $1 }')
#   fi
# fi
