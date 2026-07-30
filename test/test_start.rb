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
