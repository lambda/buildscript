require 'child_process'

class RemoteHost
  def initialize hostname, options
    @host = hostname
    @runner = options[:runner]
  end

  def run *command_line
    @runner.run('ssh', @host, *command_line)
  end

  def upload src, dst, options={}
    args = ['-r', "--delete", "--delete-excluded"]
    if options[:exclude]
      args += ["--exclude=#{options[:exclude]}"]
    end
    args += [src, "#{@host}:#{dst}"]
    @runner.run('rsync', *args)
  end
end
