require 'test/unit'
require 'Build'

# Test our one-button build system.
class TestBuilder < Test::Unit::TestCase
  # This setup is perfomed before each test method.
  def setup
    @tmpdir = "build_test_tmp"
    @build = Build.new(:build_dir => @tmpdir)
  end

  # This teardown is performed after each test method.
  def teardown
    FileUtils.rm_rf @tmpdir
  end 

  # Make sure we create a build directory.
  def test_build_dir
    assert File.directory?(@tmpdir)
  end
end
