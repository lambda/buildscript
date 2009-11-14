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
require 'buildscript/inno_setup'
require 'fileutils'

class InnoSetupTest < Test::Unit::TestCase
  include FileUtils

  # Make sure our preprocessor is at least semi-plausible.
  def test_preprocess
    assert_equal <<__EOO__, InnoSetup::preprocess(<<__EOI__, 'E' => 1)
foo
baz
external
__EOO__
#define X 1
#if X
foo
#else
bar
#endif
#ifndef Y
baz
#endif
#ifdef Z
moby
#endif Z
#ifndef E
nested define should be ignored
#define E 0
#endif
#if E
external
#endif
#if 0
#if 1
nested if shouldn't reactivate
#else
neither should this
#endif
#endif
__EOI__
  end

  # Make sure we can break a file into sections.
  def test_sections
    sections = InnoSetup::split_into_sections(<<__EOI__)
blah
[Files]
foo
bar
[Code]
baz
__EOI__
    assert_equal ["foo", "bar"], sections['Files']
    assert_equal ["baz"], sections['Code']
  end

  # Make sure we can parse Inno Setup's data line format.
  def test_decl_line
    line = 'Filename: foo; Parameters: "x ; ""y"""; Components: bar...'
    parsed = InnoSetup::parse_decl_line line
    assert_equal 'foo', parsed['Filename']
    assert_equal 'x ; "y"', parsed['Parameters']
    assert_equal 'bar...', parsed['Components']
  end

  # For convenience
  FC = InnoSetup::FileSet::FileCopy

  # Parse an actual *.iss file and see how far we get.
  def test_source_file
    iss = InnoSetup::SourceFile::new('fixtures/sample.iss', 'fixtures',
                                     'EXTRA_MEDIA' => 1)
    assert_instance_of Hash, iss.components
    assert_equal %w(base media), iss.components.values.map {|c| c.name }.sort
    fs = iss.file_sets

    # Check our simplest FileSet.
    assert_equal 'helper.txt', fs[0].source
    assert_equal ['dontcopy'], fs[0].flags
    assert_nil fs[0].dest_dir
    assert_equal([FC.new('fixtures/helper.txt', nil)], fs[0].files)

    # Check some more complicated file sets.
    assert_equal([FC.new('fixtures/README.txt', '{app}/README.txt')], 
                 fs[1].files)
    assert_equal(%W(CVS .cvsignore *.bak .\#* \#* *~ ignore\\*\\dir 
                    nested\\dir), 
                 fs[3].excludes)
    assert_equal([FC.new('fixtures/Media/foo.txt', '{app}/Media/foo.txt'),
                  FC.new('fixtures/Media2/baz.txt', '{app}/Media/baz.txt'),
                  FC.new('fixtures/Media2/sub/w.txt', '{app}/Media/sub/w.txt')],
                 iss.components['media'].files)
    assert_equal([FC.new('fixtures/README.txt', '{app}/README.txt'),
                  FC.new('fixtures/README.txt', '{app}/dir/README.txt')],
                 iss.components['base'].files)
  end

  # Generate a manifest file.
  def test_manifest
    iss = InnoSetup::SourceFile::new('fixtures/sample.iss', 'fixtures',
                                     'EXTRA_MEDIA' => 1)

    assert !iss.components['base'].includes_manifest?
    assert iss.components['media'].includes_manifest?

    null_digest = Digest::SHA1.hexdigest('')
    expected_manifest = <<__EOD__
#{null_digest} 0 Media/baz.txt
#{null_digest} 0 Media/foo.txt
#{null_digest} 0 Media/sub/w.txt
__EOD__

    manifest_digest = Digest::SHA1.hexdigest(expected_manifest)
    manifest_size = expected_manifest.size

    expected_spec = <<__EOD__
Build: 2006-01-01

#{manifest_digest} #{manifest_size} MANIFEST.media
__EOD__

    
    assert_equal expected_manifest, iss.components['media'].manifest
    assert_equal expected_spec, iss.spec_file(:Build => "2006-01-01")
  end
end
