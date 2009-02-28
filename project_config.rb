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
# The format is a subset of the semi-standard INI file format (of which
# variations are supported by various Windows utilities, Samba, wxWidgets,
# and Git).  It supports sections delimited by [ and ], key value pairs
# separated with an =, and blank lines.  It explicitly errors on common
# INI syntax that it does not understand, such as "quoted strings", \ 
# escapes, and comments denoted by ; and #.
#
# After each section heading, every key is conisdered to be in that
# section untile the next section heading.  This is represented by the
# key being stored as "section.key".  Thus,
#   [section]
#   key = val
# is equivalent to
#   section.key = val
#
# When you create a ProjectConfig object, it looks for a config file at
# config/project.conf.  It would perhaps be nice in the future to search
# up the directory hierarchy to find the top-level project dir, but it
# does not do that at this time; it simply looks for the file relative to
# the current working directory.
class ProjectConfig
  KeyRE = /[a-zA-Z0-9._-]+/
  ValRE = /[^";\\#]*[^";\\# \t]/
  def initialize
    @file = Pathname.new 'config/project.conf'
    unless @file.exist?
      raise "Could not find config/project.conf"
    end
    @items = { }
    section = nil
    @file.read.each_line do |line|
      l = line.chomp
      case l
        when /^[ \t]*$/
          # skip this line, do nothing
        when /^[ \t]*\[(#{KeyRE})\][ \t]*$/
          section = $1
        when /^[ \t]*(#{KeyRE})[ \t]*=[ \t]*(#{ValRE})[ \t]*$/
          key = if section then section + "." + $1 else $1 end
          @items[key] = $2
        else
          raise <<EOF
config/project.conf: unrecognized format in line:
#{line}
EOF
      end
    end
  end

  def [] key
    @items[key]
  end

  def print
    @items.each { |key,val| puts "#{key}=#{val}"}
  end
end
