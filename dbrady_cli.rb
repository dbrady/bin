#!/usr/bin/env ruby
require "colorize"

# mixin module to provide all the git/jira stuff I keep reusing everywhere.
#

# TODO add an optflag helper function maybe?
# e.g. optflag :pants would do def pants?; opts[:pants]; end

# The including class may wish to use opts = Optimist.options { ... }, and
# capture debug, pretend and/or quiet. See scrapbin/ruby/new-ruby (in my
# scrapbin repo) for an example.
module DbradyCli
  attr_reader :opts

  def debug?
    opts[:debug]
  end

  def quiet?
    opts[:quiet]
  end

  def verbose?
    opts[:verbose]
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

  # Log and run a command, and return its exit status.
  # Returns true if --pretend
  def run_command(command)
    puts "run_command: #{command.inspect}" if debug?
    puts command.cyan unless quiet?
    pretend? || system(command)
  end

  def get_command_output_lines(command)
    get_command_output(command).each_line.map(&:rstrip).to_a
  end

  # run a command and get its output as a single string (rstripping last line)
  def get_command_output(command)
    `#{command}`.rstrip
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

    branch.split(%r{/})[1].split(%r{-})[0..1].join('-').to_s
  end

  # get url to ticket
  def jira_url(ticket=jira_ticket)
    "https://acima.atlassian.net/browse/#{ticket}"
  end

  # Generate the markdown linkety blurb
  def markdown_link_to_jira_ticket(ticket=jira_ticket)
    "Link to Ticket: [#{jira_ticket}](#{jira_url})"
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

if __FILE__ == $0
  # This is a clever, but it's a clever
  # puts Class.new { include DbradyCli }.new.send(ARGV.first)

  class Application
    include DbradyCli
  end

  if ARGV.first
    puts Application.new.send ARGV.first
  end
end
