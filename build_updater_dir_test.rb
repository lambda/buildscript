require 'test/unit'
require 'build_updater_dir'
require 'pathname'

class BuildUpdaterDirTest < Test::Unit::TestCase
  include ManifestParser

  NullHash = 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
  FooHash = '855426068ee8939df6bce2c2c4b1e7346532a133'

  def setup
    mkdir_p 'test_build_tmp'
  end

  def teardown
    rm_rf 'test_build_tmp'
  end

  def test_parse_manifest
    manifest = parse_manifest <<END
123ABC 12 folder with space/foo.txt
45DE6F 2 bar.txt
END
    assert_equal "folder with space/foo.txt", manifest[0].filename 
    assert_equal 12, manifest[0].size
    assert_equal "123ABC", manifest[0].hash
    assert_equal "bar.txt", manifest[1].filename
  end

  def test_parse_spec_file
    spec = parse_spec_file <<END
Key: value
Another-Key: another: value

ABC123 42 MANIFEST.foo
DEAD23 31415 MANIFEST.bar
END
    
    assert_equal "value", spec["Key"]
    assert_equal "another: value", spec["Another-Key"]
    assert_equal "MANIFEST.foo", spec["MANIFEST"][0].filename
  end

  # TODO - we can probably drop this test, since the next one tests this 
  # and more.
  def test_server_installer_base
    installer = UpdateServerInstaller.new('updater-fixtures/base',
                                          'test_build_tmp')
    installer.build_update_installer

    root = Pathname.new("test_build_tmp")
    pool = root + "pool"
    manifest_dir = root + "manifests" + "base"
    
    root_list = root.entries
    assert_include root_list, Pathname.new("staging.spec")
    assert_include root_list, Pathname.new("manifests")
    assert_include root_list, Pathname.new("pool")
    
    assert_include (root+"manifests").entries, Pathname.new("base")
    assert_include manifest_dir.entries, Pathname.new("release.spec")
    assert_include manifest_dir.entries, Pathname.new("MANIFEST.base")
    assert_include manifest_dir.entries, Pathname.new("MANIFEST.sub")

    assert (root+"staging.spec").exist? # check that it points to something
    assert_equal <<EOF, (root+"staging.spec").read
Update-URL: http://www.example.com/updates/
Build: base

142b5a7005ee1b9dc5f1cc2ec329acd0ad3cc9f6 110 MANIFEST.sub
82b90fb155029800cd45f08d32df240d672dfd5b 102 MANIFEST.base
EOF
    assert_equal "", (pool+NullHash).read
  end

  def test_server_installer_update
    root = Pathname.new("test_build_tmp")
    pool = root + "pool"
    base_manifest_dir = root + "manifests" + "base"
    update_manifest_dir = root + "manifests" + "update"

    base_installer = UpdateServerInstaller.new("updater-fixtures/base",
                                               "test_build_tmp")
    base_installer.build_update_installer

    # Simulate actually releasing an update, which consists of copying 
    # staging.spec to release.spec
    copy_entry root + "staging.spec", root + "release.spec"
    
    update_installer = UpdateServerInstaller.new("updater-fixtures/update",
                                                 "test_build_tmp")
    update_installer.build_update_installer

    root_list = root.entries
    assert_include root_list, Pathname.new("staging.spec")
    assert_include root_list, Pathname.new("release.spec")
    assert_include root_list, Pathname.new("manifests")
    assert_include root_list, Pathname.new("pool")

    assert_include (root+"manifests").entries, Pathname.new("base")
    assert_include (root+"manifests").entries, Pathname.new("update")

    assert_include base_manifest_dir.entries, Pathname.new("release.spec")
    assert_include base_manifest_dir.entries, Pathname.new("MANIFEST.base")
    assert_include base_manifest_dir.entries, Pathname.new("MANIFEST.sub")

    assert_include update_manifest_dir.entries, Pathname.new("release.spec")
    assert_include update_manifest_dir.entries, Pathname.new("MANIFEST.base")
    assert_include update_manifest_dir.entries, Pathname.new("MANIFEST.sub")

    assert (root+"release.spec").exist? # check that it points to something
    assert_equal <<EOF, (root+"release.spec").read
Update-URL: http://www.example.com/updates/
Build: base

142b5a7005ee1b9dc5f1cc2ec329acd0ad3cc9f6 110 MANIFEST.sub
82b90fb155029800cd45f08d32df240d672dfd5b 102 MANIFEST.base
EOF

    assert (root+"staging.spec").exist? # check that it points to something
    assert_equal <<EOF, (root+"staging.spec").read
Update-URL: http://www.example.com/updates/
Build: update

5983ca11eaf522f579bf3dfbd998ecb557d86eed 166 MANIFEST.sub
9e25206db9d0379e536cd0ff9ef953e1f36b6898 102 MANIFEST.base
EOF

    assert_equal "", (pool+NullHash).read
    assert_equal "foo\r\n", (pool+FooHash).read
  end

  def assert_include array, item, message = nil
    message = build_message(message, '<?> does not contain <?>',
                            array, item)
    assert_block(message) do
      array.include? item
    end
  end
end
