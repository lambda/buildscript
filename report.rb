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

# A list of commands that have been run, and their output.
class Report
  # This exception is raised whenever a command fails.
  class CommandFailed < RuntimeError
  end

  # The path to the report file.  May be nil.
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

  # Close the report.
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
  private :write

  # Covert _command_ and _args_ to a formatted string for display to the
  # user.
  def Report.format_command_line command, *args
    "#{command} #{args.join(' ')}"
  end

  # Run the specified command, and pass its output to our block (if one
  # is provided).
  def Report.run_capturing_output command, *args
    # TODO - Move into ChildProcess?
    ChildProcess.exec({:combine_output => true}, command, *args) do |child|
      child.in.close
      until child.out.eof?
        # Consume output one line at a time.
        line = child.out.gets
        yield line if block_given?
      end
      unless child.wait.success?
        formatted = format_command_line command, *args
        raise CommandFailed, "Error running <#{formatted}>", caller
      end
    end    
  end
    
  # Run a shell command, and add its output to our report.  Raises
  # CommandFailed if the child process returns an error.
  def run command, *args
    formatted = Report.format_command_line command, *args
    write ">>> #{formatted}\n"
    Report.run_capturing_output(command, *args) do |data|
      write data
    end
  end
  
  # Get the report's data as text.
  def text
    @text.join('')
  end
end
