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
  def test_decl_line
    line = 'Filename: foo; Parameters: "x ; ""y"""; Components: bar...'
    parsed = InnoSetup::parse_decl_line line
    assert_equal 'foo', parsed['Filename']
    assert_equal 'x ; "y"', parsed['Parameters']
    assert_equal 'bar...', parsed['Components']
  end

  # Parse an actual *.iss file and see how far we get.
  def test_source_file
    iss = InnoSetup::SourceFile::new 'fixtures/sample.iss'
    assert_instance_of Hash, iss.components
    assert_equal %w(base media), iss.components.values.map {|c| c.name }.sort
    fs = iss.file_sets

    # Check our simplest FileSet.
    assert_equal 'helper.dll', fs[0].source
    assert_equal ['dontcopy'], fs[0].flags
    assert_nil fs[0].dest_dir
    assert_equal({'fixtures/helper.dll' => nil}, fs[0].files)

    # Check some more complicated file sets.
    assert_equal({'fixtures/README.txt' => '{app}/README.txt'}, fs[1].files)
    #assert_equal({'fixtures/Media/foo.txt' => '{app}/Media/foo.txt',
    #              'fixtures/Media2/baz.txt' => '{app}/Media/baz.txt'},
    #             iss.components['media'].files)
  end
end
