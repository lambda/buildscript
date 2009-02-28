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

require 'fileutils'

module ManifestParser
  include FileUtils

  ManifestEntry = Struct.new("ManifestEntry", :hash, :size, :filename)
  
  def parse_manifest text
    result = []
    text.each_line do |line|
      # Note: the next line needs to be a regexp instead of a string, because
      # Ruby special cases a string of a single space to mean "any whitespace"
      # and we just want to break on a single space. 
      arr = line.chomp.split(/ /, 3)
      result << ManifestEntry.new(arr[0], arr[1].to_i, arr[2])
    end
    return result
  end

  module_function :parse_manifest

  def parse_spec_file text
    result = {}
    parts = text.split("\n\n", 2)
    parts[0].each_line do |line|
      key, value = line.chomp.split(': ', 2)
      result[key] = value
    end
    result["MANIFEST"] = parse_manifest(parts[1])
    return result
  end

  module_function :parse_spec_file
end
