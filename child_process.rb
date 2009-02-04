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

require 'buildscript/assert'

# A less-broken replacement for Ruby's miscellaneous _popen_, _Open3_, and
# other modules for spawning child processes.  Works on Cygwin (and almost
# certainly on real Unix systems), but probably does not work with a native
# Win32 environment.
class ChildProcess
  # The child's standard input.
  attr_reader :in
  # The child's standard output.
  attr_reader :out
  # The child's standard error, or +nil+ if outputs are combined.
  attr_reader :err
  # The child's pid.
  attr_reader :pid

  # :call-seq:
  #   exec(options, command, *args) -> child
  #   exec(options, command, *args) {|child| ...}
  #
  # Run _command_ as a child process, passing it _args_.  If a block
  # is given, automatically clean up _child_ at the end of the block.  See
  # #new for a list of _options_.
  def ChildProcess.exec(options, command, *args)
    child = ChildProcess.new(options, command, *args)
    return child unless block_given?
    begin
      yield child
    ensure
      child.close
    end
  end

  # Create a child process running _command_, passing it _args_.  Options
  # include:
  # +combine_output+:: Merge _out_ and _err_ into a single stream.
  def initialize(options, command, *args)
    @waited = false

    # Open three pipes for our child's standard I/O.  This probably only
    # works on UNIX systems and Cygwin.
    child_in, @in = IO.pipe
    @out, child_out = IO.pipe
    if options[:combine_output]
      @err, child_err = nil, nil
    else
      @err, child_err = IO.pipe
    end
    
    # Split off a child process to run the command.
    @pid = fork do
      # In the child process, close the parent's end of each pipe.
      [@in, @out, @err].each {|f| f.close if f}

      # Rebind standard I/O for our child process.
      STDIN.reopen(child_in)
      STDOUT.reopen(child_out)
      if options[:combine_output]
        STDERR.reopen(child_out)
      else
        STDERR.reopen(child_err)
      end

      # Replace the Ruby interpreter in the child process with a copy of
      # our command, keeping the same PID.  This call never returns, and
      # the the command's exit status becomes our own.
      exec command, *args
    end

    # In the parent process, close the child's end of each pipe.
    [child_in, child_out, child_err].each {|f| f.close if f}
  end

  # Wait for the child process to complete, and return a Process::Status
  # object.
  def wait
    assert !@waited
    pid, status = Process.waitpid2(@pid)
    @waited = true
    status
  end

  # Close all I/O streams associated with the child process, and wait for
  # it to exit.
  def close
    [@in, @out, @err].each {|f| f.close if f && !f.closed? }
    wait unless @waited
  end
end
