require 'Report'
require 'test/unit'

# Test our one-button build system.
class TestReport < Test::Unit::TestCase
  # Called once for each test case.
  def setup
    @report = Report.new(:silent => true)
  end

  # Test basic report functions.
  def test_report
    @report.heading('Testing')
    @report.run('echo', 'foo')
    assert_equal ">>>>> Testing\n>>> echo foo\nfoo\n", @report.text
  end

  # Make sure we raise errors when a build command fails.
  def test_command_failed
    assert_raise(Report::CommandFailed) { @report.run('nosuch') }
    assert_raise(Report::CommandFailed) { @report.run('cat', 'nosuch') }
  end
end
