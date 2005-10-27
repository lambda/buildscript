require 'ChildProcess'

# A list of commands that have been run, and their output.
class Report
  # This exception is raised whenever a command fails.
  class CommandFailed < RuntimeError
  end

  # The path to our report file.  May be nil.
  attr_reader :path

  # Create a new Report.  Options include:
  #
  # +silent+:: Do not write report data to standard output.
  # +dir+:: A directory in which test reports should be stored.
  def initialize options
    @silent = options[:silent]
    @text = []
    @closed = false
    if options[:dir]
      @path = "#{options[:dir]}/BuildReport.txt"
      @report_file = open(@path, "w")
    end
  end
  
  # Returns true once #close has been called.
  def closed?() @closed end

  # Close our report.
  def close
    assert !@closed
    @report_file.close if @report_file
    @closed = true
  end

  # Add a new heading to the report.
  def heading str
    write ">>>>> #{str}\n"
  end
  
  # Write a chunk of data to our report.
  def write data
    assert !@closed

    # We store the text as a list so appending will be cheap.
    @text << data
    unless @silent
      $stdout.print data 
      $stdout.flush
    end
    if @report_file
      @report_file.print data
      @report_file.flush
    end
  end
  
  # Run a shell command, and add its output to our report.  Raises
  # CommandFailed if the child process returns an error.
  def run command, *args
    formatted = "#{command} #{args.join(' ')}"
    write ">>> #{formatted}\n"
    ChildProcess.exec({:combine_output => true}, command, *args) do |child|
      child.in.close
      until child.out.eof?
        # Consume output one line at a time.
        write child.out.gets
      end
      unless child.wait.success?
        raise CommandFailed, "Error running <#{formatted}>", caller
      end
    end
  end
  
  # Get the report's data as text.
  def text
    @text.join('')
  end
end
