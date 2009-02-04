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
