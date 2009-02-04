# @BEGIN_LICENSE
#
# Halyard - Multimedia authoring and playback system
# Copyright 1993-2009 Trustees of Dartmouth College
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
# USA.
#
# @END_LICENSE

require 'buildscript/child_process'
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
