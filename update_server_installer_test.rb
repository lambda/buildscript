# @BEGIN_LICENSE
#
# Halyard - Multimedia authoring and playback system
# Copyright 1993-2009 Trustees of Dartmouth College
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as
# published by the Free Software Foundation; either version 2.1 of the
# License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public
# License along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307,
# USA.
#
# @END_LICENSE

require 'test/unit'
require 'buildscript/update_server_installer'
require 'pathname'
require 'fileutils'

include FileUtils

class UpdateServerInstallerTest < Test::Unit::TestCase
  NullHash = 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
  FooHash = '855426068ee8939df6bce2c2c4b1e7346532a133'

  def setup
    rm_rf 'test_build_tmp'
    mkdir_p 'test_build_tmp'
  end

  def teardown
    rm_rf 'test_build_tmp'
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
    assert_include manifest_dir.entries, Pathname.new("release.spec.sig")
    assert_include manifest_dir.entries, Pathname.new("MANIFEST.base")
    assert_include manifest_dir.entries, Pathname.new("MANIFEST.sub")

    assert (root+"staging.spec").exist? # check that it points to something
    assert (root+"staging.spec.sig").exist? # check that it points to something
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
    copy_entry root + "staging.spec.sig", root + "release.spec.sig"
    
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
    assert (root+"release.spec.sig").exist? # check that it points to something
    assert_equal <<EOF, (root+"release.spec").read
Update-URL: http://www.example.com/updates/
Build: base

142b5a7005ee1b9dc5f1cc2ec329acd0ad3cc9f6 110 MANIFEST.sub
82b90fb155029800cd45f08d32df240d672dfd5b 102 MANIFEST.base
EOF

    assert (root+"staging.spec").exist? # check that it points to something
    assert (root+"staging.spec.sig").exist? # check that it points to something
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
