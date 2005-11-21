require 'test/unit'
require 'Build'

# Test our one-button build system.
class TestBuilder < Test::Unit::TestCase
  include FileUtils

  # This setup is perfomed before each test method.
  def setup
    @build_dir = 'test_build_tmp'
    @release_dir = 'release_test_tmp'
    @build = Build.new(:build_dir => @build_dir, :release_dir => @release_dir,
                       :silent => true)
  end

  # This teardown is performed after each test method.
  def teardown
    @build.finish unless @build.finished?

    # rm_rf our temporary directories.  Note that we use their names,
    # and not the accessors on @build, which we don't necessarily trust.
    rm_rf @build_dir
    rm_rf @release_dir
  end

  # Make sure we create a build directory.
  def test_directories
    today = Time.now.strftime '%Y-%m-%d'
    assert File.directory?(@build_dir)
    assert File.directory?("#{@release_dir}/#{today}-A")
  end

  # Upload files to our release directory.
  def test_release
    # Create a file, and mark it for release.
    cd @build_dir do
      open('test.txt', 'w') {|out| out.puts "Hello!"}
      @build.release 'test.txt', :subdir => 'Nested', :cd => 1
      mkdir 'filtered'
      cp 'test.txt', 'filtered/test.a'
      cp 'test.txt', 'filtered/test.b'
      @build.release 'filtered', :filter => /\.a$/
      cp 'test.txt', 'cd_only.txt'
      @build.release 'cd_only.txt', :cd => 1, :cd_only => true
    end

    # Finish our build.
    assert !@build.finished?
    @build.finish
    assert @build.finished?

    # Make sure all of our released files were created.
    assert File.exists?("#{@build.release_subdir}/Nested/test.txt")
    assert File.exists?("#{@build.release_subdir}/filtered/test.a")
    assert !File.exists?("#{@build.release_subdir}/filtered/test.b")
    assert !File.exists?("#{@build.release_subdir}/cd_only.txt")
    assert File.exists?("#{@build.release_subdir}/CD 1.iso")
    assert File.exists?("#{@build.release_subdir}/BuildReport.txt")
  end

  # Make sure we're getting a build report.
  def test_build_report
    assert File.exists?("#{@build_dir}/BuildReport.txt")
  end
end
