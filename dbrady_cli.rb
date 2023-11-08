#!/usr/bin/env ruby
# mixin module to provide all the git/jira I keep reusing everywhere.
# The including class should define debug?
require "colorize"

module DbradyCli
  # ----------------------------------------------------------------------
  # BASH STUFF
  # ----------------------------------------------------------------------

  # Log a command to the console, then run it, and raise an exception if fails.
  def run_command(command, quiet: false, ignore_failure: false, pretend: false)
    puts "run_command: #{command.inspect}" if debug?
    puts command.cyan unless quiet
    system(command).tap do |success|
      raise "run_command failed running #{command.inspect}" unless success || ignore_failure
    end
  end

  def osx?
    `uname -s`.strip == 'Darwin'
  end

  def linux?
    # I mean technically also Windows but lol who even uses that
    !osx?
  end

  # ----------------------------------------------------------------------
  # JIRA STUFF
  # ----------------------------------------------------------------------

  # get the jira ticket (board and id, e.g. PANTS-44) from given branch or git
  # current-branch
  def jira_ticket(branch=nil)
    branch ||= git_current_branch

    branch.split(%r{/})[1].to_s
  end

  # get url to ticket
  def jira_url(ticket=jira_ticket)
    "https://acima.atlassian.net/browse/#{ticket}"
  end

  # ----------------------------------------------------------------------
  # GIT STUFF
  # ----------------------------------------------------------------------
  def git_current_branch
    `git current-branch`.strip
  end
end
