require 'child_process'

class RemoteHost
  def initialize hostname, options
    @host = hostname
    @runner = options[:runner]
  end

  def run *command_line
    @runner.run('ssh', @host, *command_line)
  end

  # TODO - allow filtering out directories matching pattern (like .svn)
  def upload src, dst, options={}
    if options[:exclude]
      @runner.run('rsync', '-r', "--exclude=#{options[:exclude]}",
                  src, "#{@host}:#{dst}")
    else
      @runner.run('rsync', '-r', src, "#{@host}:#{dst}")      
    end
  end
end
