#!/usr/bin/env ruby
require "colorize"
require "optimist"

# TODO:
# - [ ] Add a Logger
# - [ ] Break into smaller files. DbradyCli::Shell, Jira, Git, Env, Options. Users should get all the subfiles if they require 'dbrady_cli', ditto for include DbradyCli in the code.

# - [ ] Consider upgrading this to a gem? Not until/unless I can trick bundler into sliding my gem into every bundle. Then again I have to add colorize and optimist and extralite all the time anyway? I held off of doing the gem thing because this file was churning HARD, and I didn't want to reinstall the gem every time I changed it. But now that it is stable, I think it is time to make it a gem.
# - [ ] Add a test suite
# - [ ] Add a dbrady_cli.gemspec
# - [ ] Project Ceremony
#   - [ ] Add a README.md
#   - [ ] Add a LICENSE file
#   - [ ] Add a CHANGELOG.md
#   - [ ] Add a CONTRIBUTING.md
#   - [ ] Add a CODE_OF_CONDUCT.md
#   - [ ] Add a .gitignore file
#   - [ ] Add a .rspec file
#   - [ ] Add a .rubocop.yml file
#   - [ ] Add a .yardopts file
#   - [ ] Add a .travis.yml file
#   - [ ] Add a .circleci/config.yml file
#   - [ ] Add a .github/workflows/ci.yml file
#   - [ ] Add a .github/ISSUE_TEMPLATE/bug_report.md file
#   - [ ] Add a .github/ISSUE_TEMPLATE/feature_request.md file
#   - [ ] Add a .github/PULL_REQUEST_TEMPLATE.md file

# Monkeypatch to add type: :symbol / :symbols to Optimist
module Optimist
  # Add support for type: :symbol
  class SymbolOption < Option
    register_alias :symbol
    def as_type(val) ; val.to_sym ; end
    def type_format ; "=<s>" ; end
    def parse(paramlist, _neg_given)
      paramlist.map { |pg| pg.map { |param| as_type(param) } }
    end
  end

  # Option class for handling multiple Symbols
  class SymbolArrayOption < SymbolOption
    register_alias :symbols
    def type_format ; "=<s+>" ; end
    def multi_arg? ; true ; end
  end
end

# This is my kitchen sink mixin module to make a pretty CLI app. If
# Thor had been around before I learned all the ins and outs of
# optimist, I'd use that instead. Probably. Maybe.
#
# TODO: provide a default implementation of run that parses arguments
# and takes care of basic housekeeping, then callback to on_run. The
# run method currently does a) Optimist stuff and then b) my app
# code. SOMETIMES I override/extend the optimist stuff. I would love
# it for when I create a new script to just have to put my app code in
# def run and have it wrap or advise. ("def on_run" maybe?  Tell the
# reader "this is a delegation target because there is a delegator you
# should be aware of"?) If this were a bdd/tdd feature, I want all of
# the following (or it is not more valuable than custom coding it at
# this time):
#
# 1. legacy/older code must work the same. Their def run should be honored
#    without interference.
#
# 2. new app with perfect use case, the "# APP CODE GOES HERE" is the only code
#    I put in the new method. This is the aspirational use case; get it right or
#    don't bother. So `def run; puts "Hello"; end` should be a complete app. The
#    parent's run method should do Optimist (which means banner will need to be
#    provided by this class and/or my app code should handle that. Right now the
#    Optimist code is here in the Application class because the parent class
#    needs the banner. This could easily be extracted.

# 3. New app with custom optimist options. Probably handle the same way as the
#    banner.

# 4. New app that does not want to use the optimist stuff, idk why not. I may
#    have invented this use case to back-justify completeness with my belief
#    that I should have the option to use the new run system but turn it all off
#    to use the old run system without having to abandon the Application code
#    entirely[1]. Potentially that could just be "never call Application.run. Write
#    a custom run method and in the bootstrapper, call that instead" So maybe
#    this whole paragraph is a solution looking for a problem.

# [1] Write me a sentence that tells me you had surgery today and are trying to
# code while fighting the anesthesia without telling me you had surgery today
# and are trying to code while fighting the anesthesia


module DbradyCli
  attr_reader :opts

  # opt_flag :debug, :quiet, :verbose, :pretend
  def debug?
    opts[:debug]
  end

  def headless?
    !$stdout.tty?
  end

  def quiet?
    opts[:quiet] || headless?
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
    def opt_flags
      @opt_flags ||= [:debug, :quiet, :verbose, :pretend]
    end

    def opt_readers
      @opt_readers ||= []
    end

    # opt_flag :debug will create `def debug?; opts[:debug]; end`
    # opt_flag :a, :b, :c will create a?, b? and c?
    def opt_flag(*fields)
      Array(fields).each do |field|
        flag ||= "#{field}?"
        raise "opt_flag '#{flag}' must not have hyphens" if flag.to_s.include? '-'
        opt_flags << field
        define_method flag do
          opts[field.to_sym]
        end
      end
    end

    # Promote option to reader method, e.g. opt_reader(:host) will create `def host; opts[:host]; end`
    def opt_reader(*fields)
      Array(fields).each do |field|
        raise "opt_field '#{field}' must not have hyphens" if field.to_s.include? '-'
        opt_readers << field
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

      command = "#{rails_command} runner #{caller_file} #{ARGV.map(&:inspect).join(' ')}"

      puts command.cyan
      status = system(command)
      exit status
    end
  end

  # Autoload class methods
  def self.included(including_module)
    including_module.extend ClassMethods
  end

  def opt_flags
    self.class.opt_flags
  end

  def opt_readers
    self.class.opt_readers
  end

  def dump_opts
    puts opts.sort.to_h.inspect
    puts "opt_flags: (#{opt_flags.size})"
    opt_flags.each do |flag|
      flag_method = "#{flag}?"
      puts "#{flag}: #{public_send(flag_method).inspect}"
    end
    puts "opt_readers: (#{opt_readers.size})"
    opt_readers.each do |reader|
      puts "#{reader}: #{public_send(reader).inspect}"
    end
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

  def get_command_output_lines(command, quiet: false)
    get_command_output(command, quiet:).each_line.map(&:rstrip).to_a
  end

  # run a command and get its output as a single string (rstripping last line)
  def get_command_output(command, quiet: false)
    puts command.cyan unless (quiet || quiet?)
    if pretend?
      ""
    else
      `#{command}`.rstrip
    end
  end

  def osx?
    `uname -s`.strip == 'Darwin'
  end

  def linux?
    # I mean technically also Windows/WSL but lol who even uses that
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
    repo, pr_id = `git get-pr -q`
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
    `git get-pr -q`.strip
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
    File.readlines(File.expand_path("~/.bundle/config")).detect { |line| line =~ /^BUNDLE_RUBYGEMS__PKG__GITHUB__COM:/ }.split(/:/).last.strip.gsub(/['"]/, "")
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
