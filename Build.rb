require 'ChildProcess'
require 'BuildUtils'
require 'Report'

# Implements a mini-language for describing one-button builds.
class Build
  include BuildUtils
  
  # Create a new Build. Options include:
  #
  # +build_dir+:: The directory to build into.  Will be deleted.
  def initialize options
    # Delete our build directory if it exists.  The recursive delete
    # using Find was inspired by Sean Russell in ruby-talk 43478.
    @build_dir = options[:build_dir]
    if File.exists?(@build_dir)
      countdown "Deleting #{@build_dir}"
      rm_rf @build_dir
    end
    mkdir_p @build_dir
    
    # Create a new report for this build.
    @report = Report.new(:build_dir => @build_dir)
  end
end
