# frozen_string_literal: true

require 'minitest/autorun'

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
