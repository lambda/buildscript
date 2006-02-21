require 'test/unit'
require 'Build'

module AbstractBuilderTest 
  include FileUtils
  # This setup is perfomed before each test method.
  def setup
    @build_dir = 'test_build_tmp'
    @release_dir = 'release_test_tmp'
    @build = make_build
  end

  # This teardown is performed after each test method.
  def teardown
    @build.finish unless @build.finished?

    # rm_rf our temporary directories.  Note that we use their names,
    # and not the accessors on @build, which we don't necessarily trust.
    rm_rf @build_dir
    rm_rf @release_dir
  end

  # Override to change arguments to Build.new.
  def make_build
    Build.new(:build_dir => @build_dir, :release_dir => @release_dir,
              :silent => true)
  end

  # Mock build script that will be used to test enabling and disabling of 
  # headings.
  def prepare_build_for_heading_test
    @build.heading "Plain heading."

    # This should fail because we don't support named headings that don't 
    # also include a body, since the only reason for naming is to be able 
    # to disable the body. 
    assert_raise Test::Unit::AssertionFailedError do
      @build.heading "Named heading, enabled.", :name => :enabled
    end

    @build.heading "Plain heading, body." do
      @executed_sections.push(:plain_body)
    end

    @build.heading "Named heading, enabled, body.", :name => :enabled_body do
      @executed_sections.push(:enabled_body)
    end

    @build.heading "Named heading, disabled, body.", :name => :disabled_body do
      @executed_sections.push(:disabled_body)
    end
  end  
end  

# Test our one-button build system.
class BuilderTest < Test::Unit::TestCase
  include AbstractBuilderTest

  # Make sure we create a build directory.
  def test_directories
    today = Time.now.strftime '%Y-%m-%d'
    assert !@build.dirty?
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

    assert !@build.dirty?

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

  # Make sure that when we don't disable sections, all sections are built. 
  def test_heading_enabled
    @executed_sections = []
    
    prepare_build_for_heading_test

    open("#{@build_dir}/BuildReport.txt", 'r') do |report|
      assert_equal ">>>>> Plain heading.\n", report.gets
      assert_equal ">>>>> Plain heading, body.\n", report.gets
      assert_equal ">>>>> Named heading, enabled, body.\n", report.gets
      assert_equal ">>>>> Named heading, disabled, body.\n", report.gets
      assert_equal nil, report.gets
    end

    assert_equal([:plain_body, :enabled_body, :disabled_body], 
                 @executed_sections)
  end

end

class BuilderDisabledTest < Test::Unit::TestCase
  include AbstractBuilderTest

  def make_build 
    # We need a different build object from the normal tests, since 
    @build = Build.new(:build_dir => @build_dir, :release_dir => @release_dir,
                       :silent => true, :enabled_headings => [:enabled_body])

  end
  
  # Make sure that when we do disable headings (by specifying those headings 
  # we want to build), we don't run the code associated with the disabled
  # ones, and that we're put into dirty mode. 
  def test_heading_disabled
    @executed_sections = []
    
    prepare_build_for_heading_test

    open("#{@build_dir}/BuildReport.txt", 'r') do |report|
      assert_equal ">>>>> Plain heading.\n", report.gets
      assert_equal ">>>>> Plain heading, body.\n", report.gets
      assert_equal ">>>>> Named heading, enabled, body.\n", report.gets
      assert_equal nil, report.gets
    end

    assert_equal [:plain_body, :enabled_body], @executed_sections
    assert @build.dirty?
  end
end
