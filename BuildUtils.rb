require 'FileUtils'
require 'Find'

# Assorted functions which are helpful for a build.  Many of these are used
# by the Build class, so don't add any commands which depend on the Build
# class.
module BuildUtils
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
    return Pathname.new(path).realpath
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
          cp file, file_dst
        end
      end
    else
      cp_r src, dst
    end
  end

  module_function :countdown, :absolute_path, :cp_filtered
end
