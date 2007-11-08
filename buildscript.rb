require 'build'
require 'remote_host'
require 'pathname'

# Calculate this now, while we have a fighting chance of resolving relative
# paths correctly.
$_buildscript_source_dir = Pathname.new(File.dirname(__FILE__)).realpath

# Include this module to write build scripts in a domain-specific language.
#
#   require 'buildscript'
#   include Buildscript
#
#   start_build :build_dir => 'c:/build/myproject'
#
#   heading 'Check out source code.'
#   run 'cvs', 'co', 'MyProject'
#   cd 'MyProject'
#
#   heading 'Build the project.'
#   run 'make'
#   release 'MyProject Installer.exe'
#
#   finish_build_and_upload_files
module Buildscript
  include BuildUtils
  
  # Start a new build running. See Build#new for options.
  def start_build options
    if ARGV.include? "dirty"
      ARGV.delete "dirty"
      options[:dirty_build] = true
    end
    sections = ARGV.map {|arg| arg.to_sym}
    options[:enabled_headings] = sections unless sections == []
    $build = Build.new options
    cd $build.build_dir
  end

  # Finish the build, and upload all our files to the server.  No
  # files will be uploaded for a dirty build.
  def finish_build_and_upload_files
    $build.finish
  end

  # See Build#heading.
  def heading(str, options={}, &block) $build.heading(str, options, &block) end
  # See Report#run.
  def run(command, *args) $build.run(command, *args) end
  # See Build#dirty?
  def dirty_build?() $build.dirty? end
  # See Build#release.
  def release(path, options={}) $build.release(path, options) end
  # See RemoteHost#initialize
  def remote_host(host) RemoteHost.new(host, :runner => $build) end

  def buildscript_source_dir() $_buildscript_source_dir end
  
  def release_id() $build.release_id end

  module_function :start_build, :finish_build_and_upload_files
  module_function :heading, :run, :dirty_build?, :release, :release_id
end