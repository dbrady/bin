# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'tmpdir'
require 'fileutils'
require 'yaml'

# End-to-end: real subprocess, real git repos, throwaway config. --pretend
# means no service is ever actually launched.
class StartIntegrationTest < Minitest::Test
  BIN = File.expand_path('../start', __dir__)

  def setup
    # realpath, not the raw mktmpdir path: on macOS /tmp (and /var) is a
    # symlink to /private/..., and `git rev-parse --show-toplevel` (used by
    # Scope.folder_key) always resolves through it. Writing config keys
    # against the unresolved path would make every folder-scoped lookup miss.
    @tmp = File.realpath(Dir.mktmpdir('start-test'))
    @config = File.join(@tmp, 'start.yml')
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def make_repo(name, remote: "git@github.com:acima-credit/#{name}.git")
    path = File.join(@tmp, name)
    FileUtils.mkdir_p(path)
    system('git', 'init', '-q', path, exception: true)
    system('git', '-C', path, 'remote', 'add', 'origin', remote, exception: true) if remote
    path
  end

  def start(*args, dir:)
    Open3.capture3({ 'START_CONFIG' => @config }, BIN, *args, chdir: dir)
  end

  def write_config(data)
    File.write(@config, data)
  end
end

class TestStartLaunching < StartIntegrationTest
  def test_bare_start_runs_the_default
    repo = make_repo('merchant_portal')
    write_config(<<~YAML)
      github.com/acima-credit/merchant_portal:
        default: server
        server: "bin/rails server -p 3000"
        q: "bundle exec sidekiq"
    YAML
    out, _err, status = start('-p', dir: repo)
    assert status.success?, out
    assert_includes out, 'bin/rails server -p 3000'
  end

  def test_named_service_runs_that_service
    repo = make_repo('merchant_portal')
    write_config(<<~YAML)
      github.com/acima-credit/merchant_portal:
        default: server
        server: "bin/rails server -p 3000"
        q: "bundle exec sidekiq"
    YAML
    out, _err, status = start('-p', 'q', dir: repo)
    assert status.success?, out
    assert_includes out, 'bundle exec sidekiq'
  end

  def test_works_from_a_subdirectory
    repo = make_repo('merchant_portal')
    sub = File.join(repo, 'app', 'models')
    FileUtils.mkdir_p(sub)
    write_config(<<~YAML)
      github.com/acima-credit/merchant_portal:
        server: "bin/rails server -p 3000"
    YAML
    out, _err, status = start('-p', dir: sub)
    assert status.success?, out
    assert_includes out, 'bin/rails server -p 3000'
  end

  def test_a_second_checkout_of_the_same_repo_shares_the_entry
    make_repo('amc')
    other = make_repo('amc.old', remote: 'https://github.com/acima-credit/amc')
    write_config(<<~YAML)
      github.com/acima-credit/amc:
        dev: "pnpm run start:dev"
    YAML
    out, _err, status = start('-p', 'dev', dir: other)
    assert status.success?, out
    assert_includes out, 'pnpm run start:dev'
  end

  def test_folder_entry_overrides_the_repo_entry
    repo = make_repo('merchant_portal')
    write_config(<<~YAML)
      github.com/acima-credit/merchant_portal:
        default: server
        server: "bin/rails server -p 3000"
        q: "bundle exec sidekiq"
      #{repo}:
        q: "RAILS_ENV=review bundle exec sidekiq"
    YAML
    out, _err, status = start('-p', 'q', dir: repo)
    assert status.success?, out
    assert_includes out, 'RAILS_ENV=review bundle exec sidekiq'
  end

  def test_extra_args_are_passed_through_where_the_command_says_dollar_at
    repo = make_repo('aperture')
    write_config(<<~YAML)
      github.com/acima-credit/aperture:
        server: "echo GRADLE \\"$@\\""
    YAML
    out, _err, status = start('server', '--server.port=7778', dir: repo)
    assert status.success?, out
    assert_includes out, 'GRADLE --server.port=7778'
  end

  def test_extra_args_without_dollar_at_warn_and_still_launch
    repo = make_repo('kipper')
    write_config(<<~YAML)
      github.com/acima-credit/kipper:
        server: "echo STARTED"
    YAML
    out, err, status = start('server', '--nope', dir: repo)
    assert status.success?, err
    assert_includes out, 'STARTED'
    assert_match(/\$@/, err)
  end

  def test_unknown_service_lists_what_is_available
    repo = make_repo('kipper')
    write_config(<<~YAML)
      github.com/acima-credit/kipper:
        server: "bin/rails s -p 3002"
        anycable: "anycable-go --port=3334"
    YAML
    _out, err, status = start('ghost', dir: repo)
    refute status.success?
    assert_includes err, 'ghost'
    assert_includes err, 'server'
    assert_includes err, 'anycable'
  end

  def test_no_services_names_both_keys_it_searched
    repo = make_repo('unconfigured')
    write_config("/somewhere/else:\n  x: \"echo x\"\n")
    _out, err, status = start(dir: repo)
    refute status.success?
    assert_includes err, repo
    assert_includes err, 'github.com/acima-credit/unconfigured'
    assert_includes err, 'start new'
  end

  def test_missing_config_file_is_reported_not_crashed
    repo = make_repo('kipper')
    _out, err, status = start(dir: repo)
    refute status.success?
    assert_includes err, 'start new'
  end

  def test_broken_yaml_reports_the_line_and_suggests_edit
    repo = make_repo('kipper')
    write_config("github.com/acima-credit/kipper:\n  server: \"unterminated\n   : :\n")
    _out, err, status = start(dir: repo)
    refute status.success?
    assert_includes err, 'start edit'
  end

  def test_a_non_git_folder_falls_back_to_the_folder_key
    plain = File.join(@tmp, 'plain')
    FileUtils.mkdir_p(plain)
    write_config("#{plain}:\n  srv: \"echo PLAIN\"\n")
    out, _err, status = start('-p', dir: plain)
    assert status.success?, out
    assert_includes out, 'echo PLAIN'
  end
end

class TestStartNew < StartIntegrationTest
  def test_new_at_a_repo_root_defaults_to_the_repo_scope
    repo = make_repo('merchant_portal')
    _out, err, status = start('new', 'q', 'bundle exec sidekiq', dir: repo)
    assert status.success?, err
    data = YAML.safe_load(File.read(@config))
    assert_equal 'bundle exec sidekiq', data.dig('github.com/acima-credit/merchant_portal', 'q')
  end

  def test_new_in_a_subdirectory_defaults_to_the_folder_scope
    repo = make_repo('merchant_portal')
    sub = File.join(repo, 'app')
    FileUtils.mkdir_p(sub)
    _out, err, status = start('new', 'q', 'bundle exec sidekiq', dir: sub)
    assert status.success?, err
    data = YAML.safe_load(File.read(@config))
    assert_equal 'bundle exec sidekiq', data.dig(repo, 'q')
  end

  def test_new_folder_flag_forces_the_folder_scope_at_a_repo_root
    repo = make_repo('merchant_portal')
    _out, err, status = start('new', '--folder', 'q', 'bundle exec sidekiq', dir: repo)
    assert status.success?, err
    data = YAML.safe_load(File.read(@config))
    assert_equal 'bundle exec sidekiq', data.dig(repo, 'q')
  end

  def test_new_default_flag_records_the_default
    repo = make_repo('merchant_portal')
    start('new', 'server', 'bin/rails s', dir: repo)
    _out, err, status = start('new', '--default', 'q', 'bundle exec sidekiq', dir: repo)
    assert status.success?, err
    data = YAML.safe_load(File.read(@config))
    assert_equal 'q', data.dig('github.com/acima-credit/merchant_portal', 'default')
  end

  def test_new_creates_the_config_file_and_its_directory
    repo = make_repo('merchant_portal')
    @config = File.join(@tmp, 'nested', 'dir', 'start.yml')
    _out, err, status = start('new', 'server', 'bin/rails s', dir: repo)
    assert status.success?, err
    assert File.exist?(@config)
  end

  def test_new_then_start_round_trips
    repo = make_repo('kipper')
    start('new', 'server', 'bin/rails s -p 3002', dir: repo)
    out, _err, status = start('-p', dir: repo)
    assert status.success?, out
    assert_includes out, 'bin/rails s -p 3002'
  end

  def test_new_preserves_comments_in_the_existing_file
    repo = make_repo('kipper')
    write_config("# keep me\ngithub.com/acima-credit/kipper:\n  server: \"bin/rails s\"\n")
    start('new', 'q', 'bundle exec sidekiq', dir: repo)
    assert_includes File.read(@config), '# keep me'
  end

  def test_new_rejects_an_unquoted_multi_word_command
    repo = make_repo('kipper')
    _out, err, status = start('new', 'q', 'bundle', 'exec', 'sidekiq', dir: repo)
    refute status.success?
    assert_match(/quote/i, err)
  end

  def test_new_repo_flag_outside_a_repo_is_an_error
    plain = File.join(@tmp, 'plain')
    FileUtils.mkdir_p(plain)
    _out, err, status = start('new', '--repo', 'q', 'echo q', dir: plain)
    refute status.success?
    assert_match(/remote|repo/i, err)
  end

  def test_repo_and_folder_flags_conflict
    repo = make_repo('kipper')
    _out, err, status = start('new', '--repo', '--folder', 'q', 'echo q', dir: repo)
    refute status.success?
    # Optimist's own conflicts() wording is "only one of --repo, --folder can
    # be given" -- it never contains the word "conflict", so a literal
    # /conflict/i match can never pass against real Optimist output. Assert
    # on the actual message instead of a substring that would always fail.
    assert_match(/only one of.*can be given/i, err)
    assert_includes err, '--repo'
    assert_includes err, '--folder'
  end

  def test_new_pretend_does_not_write
    repo = make_repo('kipper')
    _out, _err, status = start('-p', 'new', 'q', 'bundle exec sidekiq', dir: repo)
    assert status.success?
    refute File.exist?(@config)
  end
end
