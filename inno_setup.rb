# Map $', etc., to actual names.
require 'English'

# Interface to InnoSetup +*.iss+ files.
module InnoSetup

  # A parsed *.iss file.
  class SourceFile
    # The components described by this installer.
    attr_reader :components

    # Read and parse the +*.iss+ file at _path_.
    def initialize path
      source = File::open(path, "r") {|f| f.read }
      sections = InnoSetup::split_into_sections(InnoSetup::preprocess(source))
      @components = []
      sections['Components'].each do |line|
        next if line =~ /^\s*;/ or line =~ /^\s*$/
        @components << Component::new(InnoSetup::parse_data_line(line))
      end
    end
  end

  # A component is a set of files (and related actions) which can be
  # included in an installation.
  class Component
    # An internal name.  Never displayed to the user.
    attr_reader :name

    # Create a Component from the specified _properties_.
    def initialize properties
      @name = properties['Name']
    end
  end

  # Preprocess _text_ using the same rules as the InnoSetup preprocessor.
  def preprocess(text, defines={})
    defines = defines.dup
    result = []
    printing_stack = []
    printing = true
    text.each_line do |line|
      case line
      when /^#\s*define\s+(\w+)\s+(\w*)\s*$/
        defines[$1] = $2
      when /^#\s*if\s+(\w+)\s*$/
        printing_stack.push printing
        printing = 
          case preprocessor_expand($1, defines)
          when '0': false 
          when '1': true
          else raise "Can't parse: #{line}" end
      when /^#\s*ifdef\s+(\w+)\s*$/
        printing_stack.push printing
        printing = defines.has_key?($1)
      when /^#\s*ifndef\s+(\w+)\s*$/
        printing_stack.push printing
        printing = !defines.has_key?($1)
      when /^#\s*else\s*$/
        printing = !printing
      when /^#\s*endif\s*$/
        printing = printing_stack.pop
      when /^#.*$/
        raise "Unknown preprocessor command: #{line}"
      else
        result << line if printing
      end
    end
    raise "Missing #endif" unless printing_stack.empty?
    result.join
  end

  # Expand all the preprocessor _definitions_ in _str_.
  def preprocessor_expand str, definitions
    while definitions.has_key? str
      str = definitions[str].to_s
    end
    str
  end

  # Split _text_ into sections, split the sections into lines, and
  # store the result in a hash table by section name.  Sections begin
  # with a line of the form '[SectionName]'.
  def split_into_sections text
    result = {}
    current = nil
    text.each_line do |line|
      line.chomp!
      if line =~ /^\[(\w+)\]\s*$/
        raise "Duplicate section: #{$1}" if result[$1]
        current = []
        result[$1] = current
      else
        current << line if current
      end
    end
    result
  end

  # Parse a data line.  This is trickier than it should be, because Inno
  # Setup uses a fairly unpleasant quoting format.
  def parse_data_line line
    result = {}
    until line.empty?
      # Peel a key off our line.
      line =~ /^(; )?(\w+): / or raise "Can't parse: #{line}"
      key, line = $2, $POSTMATCH
      
      # Peel a value off our line.
      case line
      when /^([^;"]+)/
        result[key], line = $1, $POSTMATCH
      when /^"([^"]*(""[^"]*)*)"/
        str, line = $1, $POSTMATCH
        result[key] = str.gsub(/""/, '"')
      else
        raise "Can't parse argument: #{line}"
      end
    end
    result
  end

  module_function :preprocess, :preprocessor_expand, :split_into_sections
  module_function :parse_data_line
end
