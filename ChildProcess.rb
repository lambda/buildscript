# A less-broken replacement for Ruby's miscellaneous _popen_, _Open3_, and
# other modules for spawning child processes.  Works on Cygwin (and almost
# certainly on real Unix systems), but probably does not work with a native
# Win32 environment.
class ChildProcess
  # The child's standard input.
  attr_reader :in
  # The child's standard output.
  attr_reader :out
  # The child's standard error.
  attr_reader :err
  # The child's pid.
  attr_reader :pid

  # :call-seq:
  #   ChildProcess.exec(command, *args) -> child
  #   ChildProcess.exec(command, *args) {|child| ...}
  #
  # Run _command_ as a child process, passing it _args_.  If a block
  # is given, automatically clean up _child_ at the end of the block.
  def ChildProcess.exec(command, *args)
    child = ChildProcess.new(command, *args)
    return child unless block_given?
    begin
      yield child
    ensure
      child.close
    end
  end

  # Create a child process running _command_, passing it _args_.
  def initialize(command, *args)
    @waited = false

    # Open three pipes for our child's standard I/O.  This probably only
    # works on UNIX systems and Cygwin.
    child_in, @in = IO.pipe
    @out, child_out = IO.pipe
    @err, child_err = IO.pipe
    
    # Split off a child process to run the command.
    @pid = fork do
      # In the child process, close the parent's end of each pipe.
      [@in, @out, @err].each {|f| f.close}

      # Rebind standard I/O for our child process.
      STDIN.reopen(child_in)
      STDOUT.reopen(child_out)
      STDERR.reopen(child_err)

      # Replace the Ruby interpreter in the child process with a copy of
      # our command, keeping the same PID.  This call never returns, and
      # the the command's exit status becomes our own.
      exec command, *args
    end

    # In the parent process, close the child's end of each pipe.
    [child_in, child_out, child_err].each {|f| f.close}
  end

  # Wait for the child process to complete, and return a Process::Status
  # object.
  def wait
    pid, status = Process.waitpid2(@pid)
    @waited = true
    status
  end

  # Close all I/O streams associated with the child process, and wait for
  # it to exit.
  def close
    [@in, @out, @err].each {|f| f.close unless f.closed? }
    wait unless @waited
  end
end
