require 'ChildProcess'
require 'test/unit'

# Test the ChildProcess class to make sure that it works.
class TestChildProcess < Test::Unit::TestCase
  # Run a really simple command.  Ruby's _Open3_ has no trouble with this.
  def test_simple_command
    ChildProcess.exec('echo', 'foo') do |child|
      assert_equal 'foo', child.out.gets.chomp
      assert child.wait.success?
    end
  end

  # Make sure that we can detect a missing command.  This actually can't be
  # done with _Open3_.
  def test_missing_command
    ChildProcess.exec('nosuch') do |child|
      assert !child.wait.success?
    end
  end

  # Make sure we handle bidirectional communication.
  #
  # It may not actually be possible to make this kind of communication
  # completely safe against deadlocks.  You have been warned.
  def test_filter_command
    ChildProcess.exec('sed', 's/ /X/g') do |child|
      child.in.puts 'foo bar baz'
      child.in.close
      assert_equal 'fooXbarXbaz', child.out.gets.chomp
      assert child.wait.success?
    end
  end
end
