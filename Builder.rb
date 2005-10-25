require 'ChildProcess'

# A mini-language for describing one-button builds.
module Builder

  # This exception is raised whenever a build fails.
  class CommandFailed < RuntimeError
  end

  # A list of commands that have been run, and their output.
  class Report
    # Create a new Report.  Options include:
    #
    # +silent+:: Do not write report data to standard output.
    def initialize options
      @silent = options[:silent]
      @text = []
    end

    # Add a new heading to the report.
    def heading str
      write ">>>>> #{str}\n"
    end

    # Write a chunk of data to our report.
    def write data
      @text << data
      unless @silent
        print data 
        $stdout.flush
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
end
