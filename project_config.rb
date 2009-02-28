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

require 'pathname'

# This reads a projcet configuration file from config/project.conf.
# Each line has key-value pairs of the form "key = value", where 
# whitespace before and after the key and value are skipped.
#
# This is intended to eventually support walking up a directory
# hierarchy to find the config, and intended to support an INI
# file format or git config file format, but for now just supports
# basic key value pairs at a fixed location relative to the working
# directory.
class ProjectConfig
  def initialize
    @file = Pathname.new 'config/project.conf'
    unless @file.exist?
      STDERR.puts "Could not find config/project.conf"
      exit 1
    end
    @items = { }
    @file.read.each_line do |line|
      l = line.chomp
      l =~ /[ \t]*([^ \t=]+)[ \t]*=[ \t]*(.*[^ \t])[ \t]*$/
      @items[$1] = $2
    end
  end

  def [] key
    @items[key]
  end
end
