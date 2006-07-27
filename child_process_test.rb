require 'child_process'
require 'test/unit'

# Test the ChildProcess class to make sure that it works.
class ChildProcessTest < Test::Unit::TestCase
  # Run a really simple command.  Ruby's _Open3_ has no trouble with this.
  def test_simple_command
    ChildProcess.exec({}, 'echo', 'foo') do |child|
      assert_equal 'foo', child.out.gets.chomp
      assert child.wait.success?
    end
  end

  # Make sure that we can detect a missing command.  This actually can't be
  # done with _Open3_.
  def test_missing_command
    ChildProcess.exec({}, 'nosuch') do |child|
      assert !child.wait.success?
    end
  end

  # Make sure we handle bidirectional communication.
  #
  # It may not actually be possible to make this kind of communication
  # completely safe against deadlocks.  You have been warned.
  def test_filter_command
    ChildProcess.exec({}, 'sed', 's/ /X/g') do |child|
      child.in.puts 'foo bar baz'
      child.in.close
      assert_equal 'fooXbarXbaz', child.out.gets.chomp
      assert child.wait.success?
    end
  end

  # Make sure we can merge STDOUT and STDERR when calling a child
  # process.
  def test_combined_output
    ChildProcess.exec({:combine_output => true}, 'cat', 'nosuch') do |child|
      assert_equal('cat: nosuch: No such file or directory',
                   child.out.gets.chomp)
      assert !child.wait.success?
    end
  end

  # If we're running on Cygwin, make sure we can talk to native Win32
  # programs and merge their STDOUT and STDERR.
  def test_win32_combined_output
    return unless RUBY_PLATFORM =~ /cygwin/
    ChildProcess.exec({:combine_output => true}, 'xcopy') do |child|
      # This output may not actually remain the same on different versions
      # of Windows.  I need to check this.
      assert_equal('Invalid number of parameters', child.out.gets.chomp)
      assert_equal('0 File(s) copied', child.out.gets.chomp)
      assert !child.wait.success?
    end
  end
end
