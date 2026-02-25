#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'

LBS = File.expand_path('~/bin/lbs')

class LbsTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @db_path = File.join(@tmpdir, 'lbs.db')
    ENV['LBS_DB_PATH'] = @db_path
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    ENV.delete('LBS_DB_PATH')
  end

  def lbs(*args)
    out = `bash -lc "ruby #{LBS} #{args.join(' ')}" 2>&1`
    [$?, out]
  end

  def test_record_without_new_fails
    status, out = lbs('wt', '191')
    refute status.success?
    assert_match(/no stat called/, out)
  end

  def test_record_with_new_creates_and_records
    status, out = lbs('wt', '191', '--new')
    assert status.success?, "Expected success, got: #{out}"
    assert_match(/created new stat/, out)
    assert_match(/recorded 191/, out)
  end

  def test_record_existing_stat
    lbs('wt', '191', '--new')
    status, out = lbs('wt', '185')
    assert status.success?, "Expected success, got: #{out}"
    assert_match(/recorded 185/, out)
    refute_match(/created/, out)
  end

  def test_show_history
    lbs('wt', '191', '--new')
    lbs('wt', '185')
    status, out = lbs('wt')
    assert status.success?, "Expected success, got: #{out}"
    assert_match(/191/, out)
    assert_match(/185/, out)
  end

  def test_show_history_unknown_stat
    status, out = lbs('bogus')
    refute status.success?
    assert_match(/no stat called/, out)
  end

  # --date on --new stores date_format='%F', so subsequent calls show date-only
  def test_date_stored_on_new
    lbs('wt', '191', '--new', '--date')
    status, out = lbs('wt')
    assert status.success?, "Expected success, got: #{out}"
    # Should show date only (no HH:MM:SS before colon)
    lines = out.strip.split("\n").select { |l| l.match?(/^\d{4}-/) }
    refute_empty lines, "No data lines in output: #{out}"
    lines.each do |line|
      assert_match(/^\d{4}-\d{2}-\d{2}: /, line, "Expected date-only, got: #{line}")
    end
  end

  # --format on --new stores format, used on subsequent display
  def test_format_stored_on_new
    lbs('wt', '191', '--new', '--format=%8d')
    status, out = lbs('wt')
    assert status.success?, "Expected success, got: #{out}"
    assert_match(/\s+191/, out)
  end

  def test_format_used_on_record_output
    lbs('wt', '191', '--new', '--format=%8d')
    status, out = lbs('wt', '185')
    assert status.success?, "Expected success, got: #{out}"
    assert_match(/\s+185/, out)
  end

  def test_at_flag
    lbs('wt', '191', '--new', '--at=2026-01-15.09:00:00')
    status, out = lbs('wt', '--start=2026-01-01', '--end=2026-01-31')
    assert status.success?, "Expected success, got: #{out}"
    assert_match(/2026-01-15/, out)
    assert_match(/191/, out)
  end

  def test_string_values
    lbs('mood', 'green', '--new')
    status, out = lbs('mood')
    assert status.success?, "Expected success, got: #{out}"
    assert_match(/green/, out)
  end

  def test_no_args_shows_help
    status, out = lbs
    assert_match(/Usage/, out)
  end

  # CLI --date override on display even if stat was created without --date
  def test_date_cli_override
    lbs('wt', '191', '--new') # no --date, so stored as '%F %T'
    status, out = lbs('wt', '--date')
    assert status.success?, "Expected success, got: #{out}"
    lines = out.strip.split("\n").select { |l| l.match?(/^\d{4}-/) }
    refute_empty lines, "No data lines in output: #{out}"
    lines.each do |line|
      assert_match(/^\d{4}-\d{2}-\d{2}: /, line, "Expected date-only override, got: #{line}")
    end
  end

  # Column is named 'name' in both tables
  def test_column_name_consistency
    require 'extralite'
    lbs('wt', '191', '--new')
    d = Extralite::Database.new(@db_path)
    stat_cols = d.query_array("PRAGMA table_info(stats)").map { |r| r[1] }
    reading_cols = d.query_array("PRAGMA table_info(readings)").map { |r| r[1] }
    assert_includes stat_cols, 'name'
    assert_includes reading_cols, 'name'
    refute_includes reading_cols, 'stat_name'
  end
end
