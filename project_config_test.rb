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
require 'fileutils'
require 'buildscript/project_config'

class ProjectConfigTest < Test::Unit::TestCase
  def setup
    rm_rf 'test_project_tmp'
    mkdir_p 'test_project_tmp'
  end
  
  def teardown
    rm_rf 'test_project_tmp'
  end

  def setup_config config
    rm_rf 'config'
    mkdir 'config'
    File.open('config/project.conf', 'w') do |file|
      file.write config
    end
  end

  def run_test
    FileUtils::cd 'test_project_tmp' do 
      yield
    end
  end

  def assert_parsing_dies config
    assert_raise RuntimeError do
      run_test do
        setup_config config
        ProjectConfig.new
      end
    end
  end

  def test_key_value
    run_test do 
      setup_config <<EOF
key = val
another-key=another-val
	third_key	=	something
key4=blah	
thisvalue=has spaces at the end     
EOF
      p = ProjectConfig.new

      assert_equal "val", p['key']
      assert_equal "another-val", p['another-key']
      assert_equal "something", p['third_key']
      assert_equal "blah", p['key4']
      assert_equal "has spaces at the end", p['thisvalue']
    end
  end

  def test_keys_in_section
    run_test do
      setup_config <<EOF
key_without_section = val

[section]
key = something

[new-section]
key1 = first
key2 = second
EOF
      p = ProjectConfig.new

      assert_equal "val", p['key_without_section']
      assert_equal "something", p['section.key']
      assert_equal "first", p['new-section.key1']
      assert_equal "second", p['new-section.key2']
    end
  end

  def test_errors
    assert_parsing_dies "uknown"
    assert_parsing_dies '[section with space]'
    assert_parsing_dies '["sectionwithquotes"]'
    assert_parsing_dies '[section=withequals]'
    assert_parsing_dies '[section\with\escape]'
    assert_parsing_dies 'key = "value with quotes"'
    assert_parsing_dies 'key with space = value'
    assert_parsing_dies 'key = value\ with\ escapes'
    assert_parsing_dies 'key = value ; comment'
    assert_parsing_dies 'key = value # comment'
    assert_parsing_dies '\escape\in\key=value'
    assert_parsing_dies '"quote"inkey = value'
    assert_parsing_dies 'key=value with end quote"'
    assert_parsing_dies 'key/with/slash=val'
  end
end
