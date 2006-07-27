require 'fileutils'
require 'find'
require 'child_process'

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
