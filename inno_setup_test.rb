require 'test/unit'
require 'inno_setup'
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
#endif
#if E
external
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
  def test_data_line
    line = 'Filename: foo; Parameters: "x ; ""y"""; Components: bar...'
    parsed = InnoSetup::parse_data_line line
    assert_equal 'foo', parsed['Filename']
    assert_equal 'x ; "y"', parsed['Parameters']
    assert_equal 'bar...', parsed['Components']
  end

  # Parse an actual *.iss file and see how far we get.
  def test_source_file
    iss = InnoSetup::SourceFile::new 'fixtures/sample.iss'
    assert_equal %w(base media), iss.components.map {|k,v| k.name }.sort
  end
end
