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
require 'buildscript/manifest_parser'
require 'pathname'
require 'fileutils'

include FileUtils

class UpdateServerInstallerTest < Test::Unit::TestCase
  include ManifestParser
  NullHash = 'da39a3ee5e6b4b0d3255bfef95601890afd80709'
  FooHash = '855426068ee8939df6bce2c2c4b1e7346532a133'
  USI = UpdateServerInstaller

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
    #assert !manifest_dir.writable?
    
    ['release.spec', 'release.spec.sig', 
     'MANIFEST.base', 'MANIFEST.sub'].each do |file|
      assert_include manifest_dir.entries, Pathname.new(file)
      assert !(manifest_dir+file).writable?
    end
  end

  def check_pool hash, contents
    assert @pool.directory?
    assert_equal contents, (@pool+hash).read
    assert !(@pool+hash).writable?
  end

  def check_spec file, build_id
    spec_file = @root+file

    # check that these point to something
    assert spec_file.exist?, "No spec file" 
    assert (@root+(file+".sig")).exist?, "No spec sig"
    spec = parse_spec_file(spec_file.read)
    assert_equal build_id, spec["Build"] # check that we have the right spec
  end

  def check_spec_log spec, before, after, fields={ }
    log_file = @root+(spec+'.log')

    UpdateServer.parse_log(log_file.read).each do |line|
      if (line[:before] == before && line[:after] == after)
        fields.each do |key, val|
          assert_equal val, line[key]
        end
        return
      end
    end
    assert false, "Did not find log of #{before} to #{after} in #{log_file}"
  end

  def test_build_manifest_dir
    installer = USI.new('updater-fixtures/base', 'test_build_tmp')
    installer.build_manifest_dir

    check_manifest_dir 'base'
  end

  def test_populate_pool
    installer = USI.new('updater-fixtures/base', 'test_build_tmp')
    installer.populate_pool
    
    check_pool NullHash, ''
  end

  def test_server_installer_base
    installer = USI.new('updater-fixtures/base', 'test_build_tmp')
    installer.build_update_installer

    check_spec 'staging.spec', 'base'
    check_spec_log 'staging.spec', '<null>', 'base'
  end

  def test_release_from_staging
    base_installer = USI.new("updater-fixtures/base", "test_build_tmp")
    base_installer.build_update_installer
    UpdateServer.new("test_build_tmp").release_from_staging

    check_spec 'release.spec', 'base'
    check_spec_log 'release.spec', '<null>', 'base'
    check_spec 'staging.spec', 'base'
    check_spec_log 'staging.spec', '<null>', 'base'
  end

  # This is a test of an entire process, from building an update,
  # releasing one, and building a new one.
  def test_server_installer_update
    base_installer = USI.new("updater-fixtures/base", "test_build_tmp", 
                             :user => 'test-builder')
    base_installer.build_update_installer

    update_server = UpdateServer.new("test_build_tmp", :user => 'test-releaser')
    update_server.release_from_staging "v1.0"

    update_installer = USI.new("updater-fixtures/update", "test_build_tmp",
                               :user => 'test-builder')
    update_installer.build_update_installer

    check_manifest_dir 'base'
    check_manifest_dir 'update'

    check_pool NullHash, ''
    check_pool FooHash, "foo\r\n"

    check_spec 'release.spec', 'base'
    check_spec_log('release.spec', '<null>', 'base', 
                   :notes => "v1.0", :user => 'test-releaser')
    check_spec 'staging.spec', 'update'
    check_spec_log 'staging.spec', '<null>', 'base', :user => 'test-builder'
    check_spec_log 'staging.spec', 'base', 'update', :user => 'test-builder'
  end

  def assert_include array, item, message = nil
    message = build_message(message, '<?> does not contain <?>',
                            array, item)
    assert_block(message) do
      array.include? item
    end
  end
end
