module DbradyCli
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

  def gh_parent_branch
    JSON.parse(`gh pr view --json baseRefName`)["baseRefName"]
  rescue JSON::ParserError
    nil
  end

  def git_parent_or_main_branch
    parent = git_parent_branch
    if parent.nil? || parent.empty?
      git_main_branch
    else
      parent
    end
  end

  def git_files_changed
    `git files-changed`.each_line.map(&:strip)
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

  # Return true if path contains a .git/ folder or a .git file (specific instance of a submodule)
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
