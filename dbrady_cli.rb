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
  end

  # This just makes opt_flag become a class method without the extend ceremony.
  # This is peak Spooky Action at a Distance, and I don't do this in
  # production. But for my private scripts folder... yeah. Minimizing ceremony
  # FTW.
  #
  # include DbradyCli
  # opt_flag :cheese
  def self.included(including_module)
    including_module.extend ClassMethods
  end

  # ----------------------------------------------------------------------
  # BASH STUFF
  # ----------------------------------------------------------------------

  # Log a command to the console, then run it (unless --pretend), and raise an
  # exception if fails.
  # if force=true, run the command even if we're in pretend mode (use this
  # for commands that are not dangerous, like git isclean)
  def run_command!(command, force: false)
    puts "run_command!: #{command.inspect}" if debug?
    puts command.cyan unless quiet?

    success = if force
                system command
              else
                pretend? || system(command)
              end

    raise "run_command! failed running #{command.inspect}" unless success
    success
  end

  # Log and run a command (unless --pretend), and return its exit status.
  # if force=true, run the command even if we're in pretend mode (use this
  # for commands that are not dangerous, like git isclean)
  def run_command(command, force: false)
    puts "run_command: #{command.inspect} (force: #{force.inspect}, pretend: #{pretend?.inspect})" if debug?
    puts command.cyan unless quiet?

    if force
      system command
    else
      pretend? || system(command)
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
