# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'

# `start` has no .rb extension, so it is loaded rather than required. The
# `Application.new.run if __FILE__ == $PROGRAM_NAME` guard at the bottom keeps
# this side-effect free.
load File.expand_path('../start', __dir__)

class TestNormalizeRemote < Minitest::Test
  def test_scp_style_ssh_url
    assert_equal 'github.com/acima-credit/merchant_portal',
                 Scope.normalize_remote('git@github.com:acima-credit/merchant_portal.git')
  end

  def test_https_url_normalizes_to_the_same_key
    assert_equal 'github.com/acima-credit/merchant_portal',
                 Scope.normalize_remote('https://github.com/acima-credit/merchant_portal')
  end

  def test_https_url_with_dot_git_suffix
    assert_equal 'github.com/acima-credit/merchant_portal',
                 Scope.normalize_remote('https://github.com/acima-credit/merchant_portal.git')
  end

  def test_casing_is_normalized
    assert_equal 'github.com/acima-credit/merchant_portal',
                 Scope.normalize_remote('git@GitHub.com:Acima-Credit/Merchant_Portal.git')
  end

  def test_ssh_scheme_with_port
    assert_equal 'github.com/acima-credit/aperture',
                 Scope.normalize_remote('ssh://git@github.com:22/acima-credit/aperture.git')
  end

  def test_trailing_slash_is_stripped
    assert_equal 'github.com/acima-credit/kipper',
                 Scope.normalize_remote('https://github.com/acima-credit/kipper/')
  end

  def test_blank_and_nil_have_no_key
    assert_nil Scope.normalize_remote(nil)
    assert_nil Scope.normalize_remote('')
    assert_nil Scope.normalize_remote('   ')
  end
end

class TestServiceConfig < Minitest::Test
  DATA = {
    'github.com/acima-credit/merchant_portal' => {
      'default' => 'server',
      'server' => 'bin/rails server -p 3000 "$@"',
      'q' => 'bundle exec sidekiq',
      'console' => 'bin/rails console'
    },
    '/Users/davidbrady/acima/devel/review.merchant_portal' => {
      'default' => 'console',
      'q' => 'RAILS_ENV=review bundle exec sidekiq'
    },
    '/Users/davidbrady/plain' => { 'only' => 'echo hi' },
    '/Users/davidbrady/two' => { 'a' => 'echo a', 'b' => 'echo b' }
  }.freeze

  def setup
    @config = ServiceConfig.new(DATA)
  end

  def repo_only
    Location.new('/nowhere', 'github.com/acima-credit/merchant_portal')
  end

  def review
    Location.new('/Users/davidbrady/acima/devel/review.merchant_portal',
                 'github.com/acima-credit/merchant_portal')
  end

  def test_repo_services_apply_when_the_folder_has_no_entry
    assert_equal 'bundle exec sidekiq', @config.resolve(repo_only, 'q').command
  end

  def test_folder_overrides_repo_for_the_same_service_name
    assert_equal 'RAILS_ENV=review bundle exec sidekiq', @config.resolve(review, 'q').command
  end

  def test_folder_inherits_services_it_does_not_redefine
    assert_equal 'bin/rails server -p 3000 "$@"', @config.resolve(review, 'server').command
  end

  def test_folder_default_may_point_at_a_repo_level_service
    resolved = @config.resolve(review)
    assert_equal 'console', resolved.name
    assert_equal 'bin/rails console', resolved.command
  end

  def test_repo_default_is_used_when_no_name_is_given
    assert_equal 'server', @config.resolve(repo_only).name
  end

  def test_default_is_not_itself_selectable_as_a_service
    refute_includes @config.commands_for(repo_only).keys, 'default'
  end

  def test_a_lone_service_is_the_default
    location = Location.new('/Users/davidbrady/plain', nil)
    assert_equal 'only', @config.resolve(location).name
  end

  def test_several_services_and_no_default_is_ambiguous
    location = Location.new('/Users/davidbrady/two', nil)
    assert_nil @config.resolve(location)
  end

  def test_unknown_service_reports_what_is_available
    error = assert_raises(ServiceConfig::UnknownService) { @config.resolve(repo_only, 'nope') }
    assert_equal 'nope', error.name
    assert_equal %w[server q console], error.available
  end

  def test_a_default_pointing_at_a_missing_service_is_an_unknown_service
    config = ServiceConfig.new('/x' => { 'default' => 'ghost', 'real' => 'echo hi' })
    assert_raises(ServiceConfig::UnknownService) { config.resolve(Location.new('/x', nil)) }
  end

  def test_no_services_anywhere_raises
    assert_raises(ServiceConfig::NoServices) { @config.resolve(Location.new('/unknown', nil)) }
  end

  def test_a_nil_repo_key_is_harmless
    config = ServiceConfig.new('/x' => { 'a' => 'echo a' })
    assert_equal 'echo a', config.resolve(Location.new('/x', nil), 'a').command
  end

  def test_empty_config_raises_no_services
    assert_raises(ServiceConfig::NoServices) do
      ServiceConfig.new(nil).resolve(Location.new('/x', 'y'))
    end
  end
end

class TestYamlWriter < Minitest::Test
  FIXTURE = <<~YAML
    # Gradle forks bootRun from the long-lived daemon's environment and does
    # NOT forward client-side env vars, so a SERVER_PORT= prefix is silently
    # dropped. --server.port is forwarded explicitly and wins.
    github.com/acima-credit/aperture:
      default: server
      server: "./gradlew :aperture-gateway:bootRun --args='--server.port=7777' \\"$@\\""

    github.com/acima-credit/kipper:
      server: "bin/rails s -p 3002"
  YAML

  def write(text, **kwargs)
    YamlWriter.new(text).add(**kwargs)
  end

  def test_appends_a_new_scope_block_at_eof
    result = write(FIXTURE, scope: 'github.com/acima-credit/global_customer',
                            name: 'server', command: 'bin/rails s -p 3008')
    assert_includes result, "github.com/acima-credit/global_customer:\n"
    assert_includes result, %(  server: "bin/rails s -p 3008"\n)
  end

  def test_comments_survive_a_write
    result = write(FIXTURE, scope: 'github.com/acima-credit/kipper',
                            name: 'anycable', command: 'anycable-go --port=3334')
    assert_includes result, '# Gradle forks bootRun'
    assert_includes result, '# dropped. --server.port is forwarded explicitly and wins.'
  end

  def test_inserts_into_an_existing_block_without_disturbing_neighbors
    result = write(FIXTURE, scope: 'github.com/acima-credit/aperture',
                            name: 'server2', command: './gradlew --args=7778')
    assert_includes result, %(  server2: "./gradlew --args=7778"\n)
    # The kipper block must still be intact and still separated by a blank line.
    assert_includes result, "\ngithub.com/acima-credit/kipper:\n  server:"
  end

  def test_insertion_lands_inside_the_target_block
    result = write(FIXTURE, scope: 'github.com/acima-credit/aperture',
                            name: 'server2', command: 'echo two')
    lines = result.lines.map(&:chomp)
    aperture = lines.index('github.com/acima-credit/aperture:')
    kipper = lines.index('github.com/acima-credit/kipper:')
    added = lines.index('  server2: "echo two"')
    assert aperture < added, 'new entry must come after its scope key'
    assert added < kipper, 'new entry must come before the next scope key'
    # Ordering alone doesn't prove the insertion landed INSIDE the block
    # rather than in the gap before the next scope key -- both positions
    # satisfy aperture < added < kipper. The blank separator must trail the
    # new entry, not lead it, or the insertion silently jumped the gap.
    assert_includes result, %(  server2: "echo two"\n\ngithub.com/acima-credit/kipper:)
  end

  def test_rewriting_an_existing_service_replaces_it_in_place
    result = write(FIXTURE, scope: 'github.com/acima-credit/kipper',
                            name: 'server', command: 'bin/rails s -p 4002')
    assert_includes result, %(  server: "bin/rails s -p 4002"\n)
    refute_includes result, 'bin/rails s -p 3002'
    # FIXTURE's aperture block also has a `server:` key, so scope the
    # uniqueness check to the kipper block or this would count 2 by design.
    kipper_block = result.split(/\A.*kipper:\n/m).last
    assert_equal 1, kipper_block.scan(/^  server:/).length
  end

  def test_default_replaces_an_existing_default_line
    result = write(FIXTURE, scope: 'github.com/acima-credit/aperture',
                            name: 'server2', command: 'echo two', default: true)
    assert_includes result, "  default: server2\n"
    refute_includes result, "  default: server\n"
    assert_equal 1, result.scan(/^  default:/).length
  end

  def test_default_is_inserted_first_when_the_block_has_none
    result = write(FIXTURE, scope: 'github.com/acima-credit/kipper',
                            name: 'q', command: 'bundle exec sidekiq', default: true)
    lines = result.lines.map(&:chomp)
    kipper = lines.index('github.com/acima-credit/kipper:')
    assert_equal '  default: q', lines[kipper + 1]
  end

  def test_double_quotes_and_backslashes_are_escaped
    result = write('', scope: '/x', name: 'srv', command: 'bin/rails s "$@" \\ok')
    assert_includes result, %(  srv: "bin/rails s \\"$@\\" \\\\ok"\n)
    assert_equal 'bin/rails s "$@" \\ok', YAML.safe_load(result).dig('/x', 'srv')
  end

  def test_output_is_always_parseable_yaml
    result = write(FIXTURE, scope: 'github.com/acima-credit/kipper',
                            name: 'db', command: 'psql kipper_dev # not a comment: really')
    parsed = YAML.safe_load(result)
    assert_equal 'psql kipper_dev # not a comment: really',
                 parsed.dig('github.com/acima-credit/kipper', 'db')
    assert_equal 'server', parsed.dig('github.com/acima-credit/aperture', 'default')
  end

  def test_writing_to_an_empty_file
    result = write('', scope: '/x', name: 'srv', command: 'echo hi', default: true)
    assert_equal({ '/x' => { 'default' => 'srv', 'srv' => 'echo hi' } }, YAML.safe_load(result))
  end

  def test_a_file_without_a_trailing_newline_is_handled
    result = write("/a:\n  x: \"echo a\"", scope: '/b', name: 'y', command: 'echo b')
    assert_equal({ '/a' => { 'x' => 'echo a' } , '/b' => { 'y' => 'echo b' } }, YAML.safe_load(result))
  end

  # Regression: inserting into the LAST block of a file with no trailing
  # newline used to glue the new entry onto the prior line with no
  # separator, since only append_block (new-scope case) normalized the
  # missing newline -- upsert_entry (existing-scope case) did not.
  def test_inserting_into_the_last_block_of_a_file_without_a_trailing_newline
    result = write("/a:\n  x: \"1\"\n/b:\n  y: \"2\"", scope: '/b', name: 'z', command: '3')
    assert_equal({ '/a' => { 'x' => '1' }, '/b' => { 'y' => '2', 'z' => '3' } },
                 YAML.safe_load(result))
  end

  # Same gap, but through the default-insertion path: `add` upserts the
  # entry first (which now fixes the missing newline) and only then inserts
  # `default:`, so this must stay safe even though set_default's own insert
  # runs second.
  def test_setting_default_on_the_last_block_of_a_file_without_a_trailing_newline
    result = write("/a:\n  x: \"1\"\n/b:\n  y: \"2\"", scope: '/b', name: 'z', command: '3', default: true)
    assert_equal({ '/a' => { 'x' => '1' }, '/b' => { 'default' => 'z', 'y' => '2', 'z' => '3' } },
                 YAML.safe_load(result))
  end

  # Rewriting (not inserting) an entry that IS the unterminated last line:
  # the replacement line always carries its own trailing newline, so this
  # path was never actually at risk -- covered here to prove it, not because
  # it was broken.
  def test_rewriting_the_unterminated_last_line_of_a_file
    result = write("/a:\n  x: \"1\"", scope: '/a', name: 'x', command: '9')
    assert_equal({ '/a' => { 'x' => '9' } }, YAML.safe_load(result))
  end

  def test_bad_service_names_are_rejected
    assert_raises(ArgumentError) { write('', scope: '/x', name: 'has space', command: 'echo') }
    assert_raises(ArgumentError) { write('', scope: '/x', name: '', command: 'echo') }
  end

  def test_reserved_names_are_rejected
    # 'default' is a real key in the same hash as service names, so a
    # service named "default" would be unreachable and would brick bare
    # `start` for the whole scope. 'new' and 'edit' are reserved by the
    # CLI's own subcommand dispatch, so a service by either name would be
    # equally unreachable via `start <name>`.
    %w[default new edit].each do |reserved|
      error = assert_raises(ArgumentError) { write('', scope: '/x', name: reserved, command: 'echo') }
      assert_match(/reserved/i, error.message)
    end
  end
end

# `pick` is the only headline CLI path (the interactive picker) with no
# automated coverage. It shells out to selecta via IO.popen, so it is
# stubbed through the START_SELECTA env seam -- the same shape as
# START_CONFIG -- rather than adding a user-facing --selecta flag nobody
# asked for.
class TestPick < Minitest::Test
  # Generic stub: reads (and discards) the list selecta would show, then
  # either exits 1 (Ctrl-C / nothing picked) or prints whatever line the
  # test wants back -- passed via env var rather than interpolated into the
  # script text, so no shell-quoting of arbitrary test data is needed.
  STUB = <<~BASH
    #!/usr/bin/env bash
    cat > /dev/null
    if [ -n "$STUB_SELECTA_FAIL" ]; then
      exit 1
    fi
    printf '%s\\n' "$STUB_SELECTA_OUTPUT"
  BASH

  def with_stub_selecta(output: nil, fail: false)
    file = Tempfile.new('stub-selecta')
    file.write(STUB)
    file.close
    FileUtils.chmod('+x', file.path)

    original_selecta = ENV['START_SELECTA']
    original_output = ENV['STUB_SELECTA_OUTPUT']
    original_fail = ENV['STUB_SELECTA_FAIL']
    ENV['START_SELECTA'] = file.path
    ENV['STUB_SELECTA_OUTPUT'] = output
    ENV['STUB_SELECTA_FAIL'] = fail ? '1' : nil
    yield
  ensure
    ENV['START_SELECTA'] = original_selecta
    ENV['STUB_SELECTA_OUTPUT'] = original_output
    ENV['STUB_SELECTA_FAIL'] = original_fail
    file.unlink
  end

  def app
    Application.new
  end

  def formatted_line(commands, name)
    width = commands.keys.map(&:length).max
    format("%-#{width}s  %s", name, commands[name])
  end

  def test_normal_selection_resolves_the_chosen_name
    commands = { 'a' => 'echo a', 'b' => 'echo b' }
    with_stub_selecta(output: formatted_line(commands, 'b')) do
      resolved = app.send(:pick, commands)
      assert_equal 'b', resolved.name
      assert_equal 'echo b', resolved.command
    end
  end

  def test_a_name_containing_whitespace_still_resolves_correctly
    # Regression: pick used to recover the name by splitting the selected
    # line on whitespace, which truncated "two words" to "two" -- a lookup
    # miss that returned a Resolved with a nil command, which then blew up
    # downstream in exec_command! with NoMethodError on nil.cyan.
    commands = { 'two words' => 'echo TW', 'b' => 'echo b' }
    with_stub_selecta(output: formatted_line(commands, 'two words')) do
      resolved = app.send(:pick, commands)
      assert_equal 'two words', resolved.name
      assert_equal 'echo TW', resolved.command
    end
  end

  def test_ctrl_c_or_empty_selection_returns_nil
    commands = { 'a' => 'echo a' }
    with_stub_selecta(fail: true) do
      assert_nil app.send(:pick, commands)
    end
  end

  def test_empty_commands_never_shells_out_to_selecta
    with_stub_selecta(fail: true) do
      assert_nil app.send(:pick, {})
    end
  end
end
