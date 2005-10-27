require 'forwardable'
require 'pathname'

require 'ChildProcess'
require 'BuildUtils'
require 'Report'

# Implements a mini-language for describing one-button builds.
class Build
  include BuildUtils
  extend Forwardable

  # :nodoc: Holds information about a path which will be included in our
  # release.
  ReleaseInfo = Struct.new(:path, :options)

  # The directory in which this program will be built from scratch.
  attr_reader :build_dir

  # The directory in which all releases of the program can be found.  Not
  # present for dirty builds.
  attr_reader :release_dir

  # A name of the form 'YYYY-MM-DD-X', where _X_ is a letter.  Not present
  # for dirty builds.
  attr_reader :release_id

  # The subdirectory of #release_dir which will be used for this build.
  # Not present for dirty builds.
  def release_subdir
    return nil if dirty?
    "#{release_dir}/#{release_id}"
  end

  # Returns true if the build is "dirty", that is, not checked out from
  # scratch.
  def dirty?() @dirty end
  
  # Returns true once #finish has been called.
  def finished?() @finished end

  # Delegate _run_ to our @report member variable.  See Report for more
  # information.
  def_delegators :@report, :run

  # Create a new Build. Options include:
  #
  # +build_dir+:: The directory to build into.  Will be deleted.
  # +release_dir+:: The directory in which to put the release.  A new
  #                 subdirectory will be created for each release.
  # +silent+:: Don't produce any output.  Useful for test suites.
  # +dirty_build+:: If true, don't delete the build directory.
  def initialize options
    @build_dir = options[:build_dir]
    @silent = options[:silent]
    @dirty = options[:dirty_build]
    @release_dir = options[:release_dir] unless dirty?
    @finished = false
    @release_infos = []

    # Delete our build directory if it exists.
    if File.exists?(build_dir) && !dirty?
      countdown "Deleting #{build_dir}"
      rm_rf build_dir
    end
    mkdir_p build_dir
    
    # Create a new report for this build.
    @report = Report.new(:dir => build_dir, :silent => @silent)
    release @report.path

    # Set up our release directory.
    make_release_dir unless dirty?
  end

  # Indicate that a file or directory should be included in our release.
  def release path, options={}
    assert !finished?
    @release_infos << ReleaseInfo.new(absolute_path(path), options)
  end
  
  # Print a heading.  This uses our report when it's available, and $stdout
  # otherwise.
  def heading str
    if @report && !@report.closed?
      @report.heading str
    else
      puts ">>>>> #{str}" unless @silent
    end
  end

  # Finish the build, and close our report files.
  def finish
    assert !finished?
    @report.close
    upload_release_files
    @finished = true
  end

  private

  # Create a directory to hold our release files.
  def make_release_dir
    mkdir_p release_dir
    for letter in 'A'..'Z'
      candidate = Time.now.strftime("%Y-%m-%d-#{letter}")
      dir = "#{release_dir}/#{candidate}"
      unless File.directory? dir
        mkdir dir
        @release_id = candidate
        break
      end
    end
    unless @release_id
      raise RuntimeError, "Can't make 27 builds in one day", caller
    end    
  end

  # Upload all files marked for release.
  def upload_release_files
    # Print an appropriate heading
    if dirty?
      heading "Pretending to release files"
    else
      heading "Releasing files to #{release_subdir}."
    end

    # Release the individual files.
    @release_infos.each do |info|
      puts info.path unless @silent
      unless dirty?
        dest = release_subdir
        subdir = info.options[:subdir]
        dest += "/#{subdir}" if subdir
        mkdir_p dest
        cp_filtered(info.path, dest, info.options[:filter]) unless dirty?
      end
    end
  end
end

# Support for an implicit, top-level Build object.
#
#   require 'Build'
#   include BuildScript
#
#   start_build :build_dir => 'c:/build/myproject'
#   heading 'Check out source code.'
#   run 'cvs', 'co', 'MyProject'
module BuildScript
  include BuildUtils
  
  # Start a new build running. See #new for options.
  def start_build options
    $build = Build.new options
    cd $build.build_dir
  end

  # Finish the build, and upload all our files to the server.  No
  # files will be uploaded for a dirty build.
  def finish_build_and_upload_files
    $build.finish
  end

  # See Build#heading.
  def heading(str) $build.heading(str) end
  # See Report#run.
  def run(command, *args) $build.run(command, *args) end
  # See Build#dirty?
  def dirty_build?() $build.dirty? end
  # See Build#release.
  def release(path, options={}) $build.release(path, options) end

  module_function :start_build, :finish_build_and_upload_files
  module_function :heading, :run, :dirty_build?, :release
end
