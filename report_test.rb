require 'report'
require 'test/unit'

# Test our Report class.
class ReportTest < Test::Unit::TestCase
  # Called once before running each test case.
  def setup
    @report = Report.new(:silent => true)
  end

  # Called once after running each test case.
  def teardown
    @report.close
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
