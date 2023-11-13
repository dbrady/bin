#!/usr/bin/env ruby
# mixin module to provide all the git/jira I keep reusing everywhere.
# The including class should define debug?
require "colorize"

module DbradyCli
  attr_reader :opts

  def debug?
    opts[:debug]
  end

  def quiet?
    opts[:quiet]
  end

  def pretend?
    opts[:pretend]
  end

  # ----------------------------------------------------------------------
  # BASH STUFF
  # ----------------------------------------------------------------------

  # Log a command to the console, then run it, and raise an exception if fails.
  def run_command!(command, quiet: false, pretend: false)
    puts "run_command!: #{command.inspect}" if debug?
    puts command.cyan unless quiet?
    success = if pretend?
                true
              else
                system command
              end
    raise "run_command! failed running #{command.inspect}" unless success
    success
  end

  def run_command(command, quiet: false, pretend: false)
    puts "run_command: #{command.inspect}" if debug?
    puts command.cyan unless quiet
    system command unless pretend?
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

  def git_main_branch
    `git main-branch`.strip
  end
end
