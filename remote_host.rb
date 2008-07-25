require 'buildscript/child_process'

class RemoteHost
  def initialize hostname, options
    @host = hostname
    @runner = options[:runner]
    @user = options[:user]
    @user_host = if @user then "#{@user}@#{@host}" else @host end 
  end

  def run *command_line
    @runner.run('ssh', @user_host, *command_line)
  end

  def upload src, dst, options={}
    args = ['-r', "--delete", "--delete-excluded"]
    if options[:exclude]
      args += ["--exclude=#{options[:exclude]}"]
    end
    args += [src, "#{@user_host}:#{dst}"]
    @runner.run('rsync', *args)
  end
end
