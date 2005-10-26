require 'forwardable'
require 'ChildProcess'
require 'BuildUtils'
require 'Report'

# Implements a mini-language for describing one-button builds.
class Build
  include BuildUtils
  extend Forwardable

  attr_reader :build_dir
  
  # Create a new Build. Options include:
  #
  # +build_dir+:: The directory to build into.  Will be deleted.
  # +dirty_build+:: If true, don't delete the build directory.
  def initialize options
    # Delete our build directory if it exists.
    @build_dir = options[:build_dir]
    if File.exists?(@build_dir) && !options[:dirty_build]
      countdown "Deleting #{@build_dir}"
      rm_rf @build_dir
    end
    mkdir_p @build_dir
    
    # Create a new report for this build.
    @report = Report.new(:dir => @build_dir)
  end

  # Finish the build, and close our report files.
  def finish
    @report.close
  end

  # Delegate _run_ and _heading_ to our @report member variable.  See
  # Report for more information.
  def_delegators :@report, :heading, :run
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

  # I wonder if I can get this to work somehow?
  #def_delegators :$build, :heading, :run

  # See Report#heading.
  def heading(str) $build.heading(str) end
  # See Report#run.
  def run(command, *args) $build.run(command, *args) end

  module_function :start_build, :heading, :run
end

