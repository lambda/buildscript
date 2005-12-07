# Map $', etc., to actual names.
require 'English'
require 'pathname'
require 'digest/sha1'

# Interface to InnoSetup +*.iss+ files.
module InnoSetup

  # A parsed *.iss file.
  class SourceFile
    # The base directory for finding source files.
    attr_reader :base_dir
    # The Components described by this installer.
    attr_reader :components
    # The FileSets described by this installer.
    attr_reader :file_sets

    # Read and parse the +*.iss+ file at _path_.
    def initialize path
      @base_dir = File::dirname path
      source = File::open(path, "r") {|f| f.read }
      sections = InnoSetup::split_into_sections(InnoSetup::preprocess(source))
      cs = parse_section sections['Components'], Component
      @components = build_hash(cs) {|c| c.name }
      @file_sets = parse_section sections['Files'], FileSet
    end

    private

    # Build a hash table by iterating over a list.
    def build_hash items
      result = {}
      items.each do |v|
        k = yield v
        if result.has_key? k
          raise "Duplicate hash key: #{k} with values #{v} and #{result[k]}"
        end
        result[k] = v
      end
      result
    end

    # Parse _section_ as series of declarations, constructing an
    # instance of _klass_ for each.
    def parse_section section, klass
      result = []
      section.each do |line|
        next if line =~ /^\s*;/ || line =~ /^\s*$/
        result << klass::new(self, InnoSetup::parse_decl_line(line))
      end
      result
    end
  end

  # A Component is a set of files (and related actions) which can be
  # included in an installation.
  class Component
    # An internal name.  Never displayed to the user.
    attr_reader :name

    # Create a Component from the specified _properties_.
    def initialize iss_file, properties
      @iss_file = iss_file
      @name = properties['Name']
    end

    # For each FileSet in this component, call FileSet#files and merge
    # the results.
    def files
      fsets = @iss_file.file_sets.select {|fs| fs.components.include? name }
      merge_hashes(fsets.map {|fs| fs.files })
    end

    # Compute the manifest of a set of files.
    def manifest
      result = []
      app_prefix = /^\{app\}\//
      files.each do |path, installed_path|
        next unless installed_path =~ app_prefix
        digest = Digest::SHA1.hexdigest(IO.read(path))
        result << [digest, installed_path.gsub(app_prefix, '')]
      end
      result.sort_by {|x| x[1] }.map {|x| "#{x[0]} #{x[1]}\n" }.join
    end

    private

    def merge_hashes hashes
      result = {}
      hashes.each do |h|
        result.merge!(h) {|k,v1,v2| raise "Duplicate hash key: #{k}" }
      end
      result
    end
  end

  # A single line from the +[Files]+ section, corresponding to zero or more
  # actual files.
  class FileSet
    # A source specification.
    attr_reader :source
    # Various flags, represented as an array of strings.
    attr_reader :flags
    # The directory in which to place these files.
    attr_reader :dest_dir
    # File patterns to exclude from this file set.
    attr_reader :excludes
    # The components to which this FileSet belongs.
    attr_reader :components

    # Create a FileSet from the specified _properties_.
    def initialize iss_file, properties
      @iss_file = iss_file
      @source = properties['Source']
      @flags = (properties['Flags'] || '').split(' ')
      @dest_dir = properties['DestDir']
      @excludes = (properties['Excludes'] || '').split(',')
      @components = (properties['Components'] || '').split(' ')
    end

    # Get the source and destination paths for all files in this FileSet.
    # The source paths should point to the local filesystem.  The
    # destination paths may be +nil+ (for files which don't get installed),
    # or may begin with a directory pattern such as +{app}+.
    def files
      src_dir, src_glob = source_dir_and_glob
      src_base = cleanpath "#{@iss_file.base_dir}/#{src_dir}"
      src_ruby_glob = translate_glob src_glob
      files = apply_exclusions(expand_glob_in_dir(src_ruby_glob, src_base))
      
      # Build our result list.
      result = {}
      files.each do |f|
        src = "#{src_base}/#{f}"
        dst = dest_path_for_file f
        result[src] = dst
      end

      # Fail on empty filesets, unless they're allowed.
      if result.empty? && !flags.include?('skipifsourcedoesntexist')
        raise "Unexpected empty file set: #{source}"
      end
      result
    end

    private

    # Split our 'Source' into a directory and a glob component.
    def source_dir_and_glob
      path = fix_path source
      dir, glob = File.dirname(path), File.basename(path)
      raise "Can't handle ISS pattern #{source}" if dir.include?('*')
      return dir, glob
    end

    # Translate a glob from ISS format to Ruby format.
    def translate_glob iss_glob
      raise "Can't expand path #{iss_glob}" if iss_glob.include?('**')
      prefix = flags.include?('recursesubdirs') ? "**/" : ""
      "#{prefix}#{iss_glob}"
    end

    def expand_glob_in_dir glob, dir
      Dir.chdir(dir) { Dir[glob] }
    end

    # If any path in _path_ has a component mentioned in our 'Excludes'
    # list, then remove that name from our list.  This filters out CVS
    # directories and whatnot.
    def apply_exclusions paths
      paths.reject do |path|
        path.split("/").any? do |component|
          excludes.any? do |pattern|
            File.fnmatch(pattern, component)
          end
        end
      end
    end

    def cleanpath path
      Pathname.new(path).cleanpath.to_s
    end

    def dest_path_for_file file
      if flags.include?('dontcopy')
        nil
      else
        "#{fix_path(dest_dir)}/#{file}"
      end
    end

    def fix_path path
      path.gsub /\\/, '/'
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
      when /^#\s*endif(\s+(\w+))?\s*$/
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
  def parse_decl_line line
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
  module_function :parse_decl_line
end
