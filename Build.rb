require 'forwardable'
require 'pathname'

require 'ChildProcess'
require 'BuildUtils'
require 'Report'

# Implements a mini-language for describing one-button builds.
class Build
  include BuildUtils
  extend Forwardable

  # Holds information about a path which will be included in our release.
  ReleaseInfo = Struct.new(:path, :options) #:nodoc:

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
    @enabled_headings = options[:enabled_headings]
    @dirty = options[:dirty_build] || (@enabled_headings && true)
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
  #
  # +subdir+:: Copy _path_ into the specified subdirectory of #release_subdir.
  # +filtered+:: Only copy files matching a regular expression.  _path_ must
  #              be a directory.
  # +cd+:: Place a copy of this file on the specified CD.
  # +cd_only+:: Do not put a copy of this file in the upload directory.
  #
  # The following code releases a directory "Text Files/Extras" containing
  # files with the extension +txt+.
  #
  #   release('Text Files', :cd => 2, :subdir => 'Extras',
  #           :filtered => /\.txt$/)
  def release path, options={}
    assert !finished?
    @release_infos << ReleaseInfo.new(absolute_path(path), options)
  end
  
  # Print a heading, and execute the corresponding body of code, if this 
  # section is not disabled.  This uses Report when it's available, and 
  # +$stdout+ otherwise.
  def heading str, options={}
    # We want to make sure that every named heading has an associated block, 
    # because the only reason to name a heading is to be able to disable the 
    # associated block.
    assert block_given? if options[:name]
    if should_execute_section?(options[:name])
      if @report && !@report.closed?
        @report.heading str
      else
        puts ">>>>> #{str}" unless @silent
      end
      yield if block_given?
    end
  end

  # Finish the build, and close our report files.
  def finish
    assert !finished?
    cds = @release_infos.collect {|i| i.options[:cd]}.compact.sort.uniq
    cds.each {|n| make_cd n}
    @report.close
    upload_release_files
    @finished = true
  end

  private

  # Should we execute a section with a given name? True if we have a name 
  # and it's on the list of sections to execute, we don't have a name, or 
  # we don't have a list of sections to execute, which means execute all by
  # default. 
  def should_execute_section? name
    !name || !@enabled_headings || @enabled_headings.include?(name)
  end

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

  # Make a CD image.
  def make_cd number
    # Create a directory of files to place on the CD.
    heading "Gathering files for CD #{number}"
    cd_dir = "#{build_dir}/cd#{number}"
    mkdir_p cd_dir
    @release_infos.each do |info|
      cp_release_files(info, cd_dir) if info.options[:cd] == number
    end
    
    # Build an ISO.
    heading "Building ISO for CD #{number}"
    cd cd_dir do
      iso_file = "../CD #{number}.iso"
      files = Dir.entries('.').select {|name| name != '.' && name != '..'}
      run 'mkisofs', '-J', '-R', '-o', iso_file, *files
      release iso_file
    end
    rm_r cd_dir
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
      next if info.options[:cd_only]
      puts info.path unless @silent      
      cp_release_files info, release_subdir unless dirty?
    end
  end

  # Copy the files specified by a ReleaseInfo object to the specified
  # destination directory.
  def cp_release_files info, dst
    subdir = info.options[:subdir]
    dst = "#{dst}/#{subdir}" if subdir
    mkdir_p dst
    cp_filtered info.path, dst, info.options[:filter]
  end
end

# Include this module to write build scripts in a domain-specific language.
#
#   require 'Build'
#   include BuildScript
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
module BuildScript
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

  module_function :start_build, :finish_build_and_upload_files
  module_function :heading, :run, :dirty_build?, :release
end
