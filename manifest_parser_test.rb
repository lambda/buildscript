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
require 'buildscript/manifest_parser'
require 'pathname'
require 'fileutils'

include FileUtils

class ManifestParserTest < Test::Unit::TestCase
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
end
