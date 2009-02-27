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
    @root = Pathname.new('test_build_tmp')
    @pool = @root + 'pool'
    @manifests = @root + 'manifests'
  end

  def teardown
    chmod_R 0755, 'test_build_tmp'
    rm_rf 'test_build_tmp'
  end

  def check_manifest_dir build_id
    manifest_dir = @manifests + build_id
    assert @manifests.directory?
    assert manifest_dir.directory?
    assert !manifest_dir.writable?
    
    ['release.spec', 'release.spec.sig', 
     'MANIFEST.base', 'MANIFEST.sub'].each do |file|
      assert_include manifest_dir.entries, Pathname.new(file)
      assert !(manifest_dir+file).writable?
    end
  end

  def check_pool hash, contents
    assert @pool.directory?
    assert_equal contents, (@pool+hash).read
  end

  def check_spec file, contents
    assert (@root+file).exist? # check that it points to something
    assert (@root+(file+".sig")).exist? # check that it points to something
    assert_equal contents, (@root+file).read
  end

  def test_build_manifest_dir
    installer = UpdateServerInstaller.new('updater-fixtures/base', 
                                          'test_build_tmp')
    installer.build_manifest_dir

    check_manifest_dir 'base'
  end

  def test_populate_pool
    installer = UpdateServerInstaller.new('updater-fixtures/base', 
                                          'test_build_tmp')
    installer.populate_pool
    
    check_pool NullHash, ''
  end

  def test_server_installer_base
    installer = UpdateServerInstaller.new('updater-fixtures/base',
                                          'test_build_tmp')
    installer.build_update_installer

    check_spec 'staging.spec', <<EOF
Update-URL: http://www.example.com/updates/
Build: base

142b5a7005ee1b9dc5f1cc2ec329acd0ad3cc9f6 110 MANIFEST.sub
82b90fb155029800cd45f08d32df240d672dfd5b 102 MANIFEST.base
EOF
  end

  # This is a test of an entire process, from building an update,
  # releasing one, and building a new one.
  def test_server_installer_update
    base_installer = UpdateServerInstaller.new("updater-fixtures/base",
                                               "test_build_tmp")
    base_installer.build_update_installer

    # Simulate actually releasing an update, which consists of copying 
    # staging.spec to release.spec
    copy_entry @root + "staging.spec", @root + "release.spec"
    copy_entry @root + "staging.spec.sig", @root + "release.spec.sig"
    
    update_installer = UpdateServerInstaller.new("updater-fixtures/update",
                                                 "test_build_tmp")
    update_installer.build_update_installer

    check_manifest_dir 'base'
    check_manifest_dir 'update'

    check_pool NullHash, ''
    check_pool FooHash, "foo\r\n"

    check_spec 'release.spec', <<EOF
Update-URL: http://www.example.com/updates/
Build: base

142b5a7005ee1b9dc5f1cc2ec329acd0ad3cc9f6 110 MANIFEST.sub
82b90fb155029800cd45f08d32df240d672dfd5b 102 MANIFEST.base
EOF

    check_spec 'staging.spec', <<EOF
Update-URL: http://www.example.com/updates/
Build: update

5983ca11eaf522f579bf3dfbd998ecb557d86eed 166 MANIFEST.sub
9e25206db9d0379e536cd0ff9ef953e1f36b6898 102 MANIFEST.base
EOF
  end

  def assert_include array, item, message = nil
    message = build_message(message, '<?> does not contain <?>',
                            array, item)
    assert_block(message) do
      array.include? item
    end
  end
end
