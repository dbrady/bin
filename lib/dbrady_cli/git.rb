require "open3"

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

  # returns true if we're currently in a conflicted merge
  def git_is_merge_conflict
    success = run_command "git diff --quiet --diff-filter=U"
    !success
  end

  # Return true if path contains a .git/ folder or a .git file (specific instance of a submodule)
  def is_git_repo?(path)
    File.exist?(File.join(path, '.git'))
  end

  # Root of the main checkout for path, shared by all of its linked worktrees;
  # a submodule resolves to its own root. Raises if path is not inside a git
  # repository. Use git_working_tree_for to find files on disk.
  def git_repo_for(path)
    git_dir, common_git_dir, working_tree = git_directories_for(path)
    return working_tree if git_dir == common_git_dir

    File.dirname(common_git_dir)
  end

  # Root of the working tree containing path, i.e. where its files live.
  def git_working_tree_for(path)
    git_directories_for(path).last
  end

  # Returns [git_dir, common_git_dir, working_tree_root] for path. Raises if
  # path is not inside a git repository.
  def git_directories_for(path)
    path = File.dirname(path) if File.file?(path)
    inherited_git_variables = %w[GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR].to_h { |name| [name, nil] }
    output, stderr, status = Open3.capture3(
      inherited_git_variables,
      "git", "-C", path, "rev-parse", "--path-format=absolute",
      "--git-dir", "--git-common-dir", "--show-toplevel"
    )
    raise "FIGURE OUT PATH FOR #{path.inspect}: #{stderr.strip}" unless status.success?

    output.lines.map(&:chomp)
  end

  # Get the latest GitHub Personal Access Token
  # It's in ~/.bundle/config as
  def github_pat
    File.readlines(File.expand_path("~/.bundle/config")).detect { |line| line =~ /^BUNDLE_RUBYGEMS__PKG__GITHUB__COM:/ }.split(/:/).last.strip.gsub(/['"]/, "")
  end
end
