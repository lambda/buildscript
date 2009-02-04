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
require 'find'
require 'buildscript/child_process'

# Assorted functions which are helpful for a build.
module BuildUtils
  # Because this module is used by Build, it shouldn't contain any functions
  # which depend on build.

  # This module provides a full set of +cp+, +rm+ and other filesystem
  # functions.
  include FileUtils

  # Give the user 5 seconds to abort the build before performing the
  # described action.
  #
  #   countdown "Deleting /home"
  def countdown description
    STDERR.puts "#{description} in 5 seconds, Control-C to abort."
    (1..5).each do |i|
      STDERR.print "\a" unless i > 3 # Terminal bell.
      STDERR.print "[#{i}] "
      sleep 1
    end
    STDERR.puts
  end

  # Convert _path_ to an absolute path.  Equivalent to Pathname.realpath,
  # but with support for some of the funkier Cygwin paths.
  def absolute_path path
    # Look for drive letters and '//SERVER/' paths.
    patterns = [%r{^[A-Za-z]:(/|\\)}, %r{^(//|\\\\)}]
    patterns.each {|patttern| return path if path =~ patttern }
    absolute = Pathname.new(path).realpath
    absolute.to_s.sub(%r{^/cygdrive/(\w)/}, '\\1:/')
  end

  # Copy _src_ to _dst_, recursively.  Uses an external copy program
  # for improved performance.
  def cp_r src, dst
    Report.run_capturing_output('cp', '-r', src, dst)
  end

  # Copy _src_ into _dst_ recursively.  If _filter_ is specified, only
  # copy files it matches.
  #  cp_filtered 'Media', 'release_dir', /\.mp3$/
  def cp_filtered src, dst, filter=nil
    mkdir_p dst
    if filter
      dst_absolute = absolute_path dst
      cd File.dirname(src) do
        Find.find(File.basename(src)) do |file|
          next if File.directory? file
          next unless file =~ filter
          file_dst = "#{dst_absolute}/#{File.dirname(file)}"
          mkdir_p file_dst
          cp_r file, file_dst
        end
      end
    else
      cp_r src, dst
    end
  end

  module_function :countdown, :absolute_path, :cp_filtered
end
