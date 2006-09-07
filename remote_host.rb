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
  def upload src, dst
    @runner.run('scp', '-r', src, "#{@host}:#{dst}")
  end
end
