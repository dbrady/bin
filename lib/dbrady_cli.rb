#!/usr/bin/env ruby
require "colorize"

# DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER
#  DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGE
# R DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANG
# ER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DAN
#
# THIS FILE HAS MOVED. IT NOW LIVES IN bin/lib/. ALL NEW SCRIPTS WILL
# USE require_relative "lib/dbrady_cli".
#
# AS OF TODAY (2025-03-10) THERE ARE 45 FILES IN bin THAT require_relative
# "dbrady_cli". UPDATE THESE AND THEN REMOVE THIS COMMENT.
#
# GER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DA
# NGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER D
# ANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER
# DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER DANGER


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

  # ======================================================================
  # CLASS METHODS
  # ----------------------------------------------------------------------
  module ClassMethods
    # opt_flag :debug will create `def debug?; opts[:debug]; end`
    # opt_flag :a, :b, :c will create a?, b? and c?
    def opt_flag(*fields)
      Array(fields).each do |field|
        flag ||= "#{field}?"
        raise "opt_flag '#{flag}' must not have hyphens" if flag.to_s.include? '-'
        define_method flag do
          opts[field.to_sym]
        end
      end
    end

    # Promote option to reader method, e.g. opt_reader(:host) will create `def host; opts[:host]; end`
    def opt_reader(*fields)
      Array(fields).each do |field|
        raise "opt_field '#{field}' must not have hyphens" if field.to_s.include? '-'
        define_method field do
          opts[field.to_sym]
        end
      end
    end

    def ensure_rails_runner!
      return if defined? Rails

      # get the file path of the caller so we can pass it to rails runner.
      caller_file = caller_locations(1, 1).first.path

      # favor the spring binstub over bundler, because spring go fast.
      spring = File.join(Dir.pwd, "bin/rails")

      rails_command = File.exist?(spring) ? spring : "bundle exec rails"

      command = "#{rails_command} runner #{caller_file} #{ARGV * ' '}"

      puts command.cyan
      status = system(command)
      exit status
    end
  end

  def self.included(including_module)
    including_module.extend ClassMethods
  end
  # ----------------------------------------------------------------------
  # END CLASS METHODS
  # ======================================================================


  # ----------------------------------------------------------------------
  # BASH STUFF
  # ----------------------------------------------------------------------

  # Log a command to the console, then run it (unless --pretend), and raise an
  # exception if fails.
  # if force=true, run the command even if we're in pretend mode (use this
  # for commands that are not dangerous, like git isclean)
  def run_command!(command, force: false, env: {})
    puts "run_command!: #{command.inspect}" if debug?
    puts command.cyan unless quiet?

    success = if force
                system env, command
              else
                pretend? || system(env, command)
              end

    raise "run_command! failed running #{command.inspect}" unless success
    success
  end

  # Log and run a command (unless --pretend), and return its exit status.
  # if force=true, run the command even if we're in pretend mode (use this
  # for commands that are not dangerous, like git isclean)
  def run_command(command, force: false, quiet: false, env: {})
    puts "run_command: #{command.inspect} (force: #{force.inspect}, pretend: #{pretend?.inspect})" if debug?
    command_pieces = env.map {|pair| pair.join('=')} + [command]
    command_text = command_pieces.compact * ' '
    puts command_text.cyan unless (quiet || quiet?)

    if force
      system env, command
    else
      pretend? || system(env, command)
    end
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
    "https://upbd.atlassian.net/browse/#{ticket}"
  end

  # Generate the markdown linkety blurb
  def markdown_link_to_jira_ticket(ticket=jira_ticket)
    "Link to Ticket: [#{jira_ticket}](#{jira_url})"
  end

  # ----------------------------------------------------------------------
  # GIT STUFF
  # ----------------------------------------------------------------------
  def git_on_main_branch?
    git_current_branch == git_main_branch
  end

  def git_current_branch
    `git current-branch`.strip
  end

  def git_main_branch
    `git main-branch`.strip
  end

  def git_parent_branch
    `git parent-branch`.strip
  end

  def git_parent_or_main_branch
    parent = git_parent_branch
    if parent.nil? || parent.empty?
      git_main_branch
    else
      parent
    end
  end

  def get_board_and_ticket_from_branch
    board, ticket = `git current-branch`
                      .strip
                      .sub(%r|^dbrady/|, "")
                      .sub(%r|/.*$|, "")
                      .split(/-/)

    # puts ">>> #{[board, ticket].inspect} <<<"
    [board, ticket]
  end

  def get_repo_and_pr_from_branch
    repo, pr_id = `git get-pr`
                    .strip
                    .sub(%r|https://github.com/acima-credit/|, "")
                    .split(%r|/pull/|)

    # puts ">>> #{[repo, pr_id].inspect} <<<"
    [repo, pr_id]
  end

  def get_repo_from_branch
    get_repo_and_pr_from_branch.first
  end

  def get_pr_url
    `git get-pr`.strip
  end

  # returns true if there are no outstanding changes to commit or stash
  def git_isclean
    run_command "git isclean", force: true
  end

  # Return true if path contains a .git/ folder or a .git file (specific instance of a submodule)#
  # Duplicate code in git-branch-history and git-log-branch. Is it make-a-git-tools-gem o'clock yet?
  def is_git_repo?(path)
    File.exist?(File.join(path, '.git'))
  end

  # Walk up file tree looking for a .git folder
  # Duplicate code in git-branch-history and git-log-branch. Is it make-a-git-tools-gem o'clock yet?
  def git_repo_for(path)
    starting_path = last_path = path

    while !path.empty?
      return path if is_git_repo?(path)
      last_path, path = path, File.split(path).first
      raise "FIGURE OUT PATH FOR #{starting_path.inspect}" if last_path == path
    end
  end

  # Get the latest GitHub Personal Access Token
  # It's in ~/.bundle/config as
  def github_pat
    File.readlines(File.expand_path("~/.bundle/config")).detect { |line| line =~ /^BUNDLE_RUBYGEMS__PKG__GITHUB__COM:/ }.split(/:/).last.strip
  end
end

if __FILE__ == $0
  # If you run this file as a script, it will call the method and args you give it.
  # E.g. ruby dbrady_cli.rb is_git_repo? ~/acima/devel/merchant_portal

  class Application
    include DbradyCli
  end

  if ARGV.first
    puts Application.new.send(*ARGV).inspect
  end
end
