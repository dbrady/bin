#!/usr/bin/env ruby
require "colorize"
require "json"
require "optimist"

# TODO:
# - [ ] Add a Logger
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

# Load order matters: options defines ClassMethods, core uses it in self.included
require_relative "dbrady_cli/options"
require_relative "dbrady_cli/core"
require_relative "dbrady_cli/logging"
require_relative "dbrady_cli/shell"
require_relative "dbrady_cli/jira"
require_relative "dbrady_cli/git"

module DbradyCli
  # All methods mixed in from subfiles above.
  # `require 'dbrady_cli'` + `include DbradyCli` works exactly as before.
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
