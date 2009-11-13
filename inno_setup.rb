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

# Map $', etc., to actual names.
require 'english'
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
    def initialize path, base_dir, defines
      @base_dir = base_dir
      source = File::open(path, "r") {|f| f.read }
      preprocessed = InnoSetup::preprocess(source, defines)
      sections = InnoSetup::split_into_sections(preprocessed)
      cs = parse_section sections['Components'], Component
      @components = build_hash(cs) {|c| c.name }
      @file_sets = parse_section sections['Files'], FileSet
    end

    # Create a +.spec+ file, listing the versions of all of the components,
    # along with the build information specified.
    def spec_file params
      file = ""
      params.each do |k,v|
        file << "%s: %s\n" % [k, v]
      end
      file << "\n"
      @components.each do |name, component|
        next unless component.includes_manifest?
        file << component.manifest_meta 
        file << "\n"
      end
      file
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

    # Get all the file sets associated with this component.
    def file_sets
      @iss_file.file_sets.select {|fs| fs.components.include? name }
    end

    # For each FileSet in this component, call FileSet#files and merge
    # the results.
    def files
      merge_hashes(file_sets.map {|fs| fs.files })
    end

    # Compute the manifest of a set of files.
    def manifest
      return @manifest if @manifest
      result = []
      app_prefix = /^\{app\}\//
      manifest_regexp = /#{manifest_name}$/
      files.each do |path, installed_path|
        next unless installed_path =~ app_prefix
        # Skip the MANIFEST file if it already exists. Should only happen 
        # when doing a dirty build. 
        # TODO - we should only skip if we're doing a dirty build; if we're 
        # doing a normal build, and have a preexisting manifest, we should 
        # fail hard. 
        next if path =~ manifest_regexp 
        digest = Digest::SHA1.hexdigest(IO.read(path))
        # TODO - Should use a struct, not an array.
        result << [digest, File.size(path), 
                   installed_path.gsub(app_prefix, '')]
      end
      @manifest = 
        result.sort_by {|x| x[2] }.map {|x| "#{x[0]} #{x[1]} #{x[2]}\n" }.join
    end

    # The name of the MANIFEST file for this component.
    def manifest_name
      "MANIFEST.#{name}"
    end

    # Does this component include a MANIFEST._name_ file?  This should
    # be a single, non-wildcarded declaration of the form:
    #
    #   Source: MANIFEST.name; DestDir: {app}; \
    #     Flags: skipifsourcedoesntexist; Components: name
    #
    # ...where _name_ is the name of this component.
    def includes_manifest?
      file_sets.any? {|fs| fs.source == manifest_name }
    end

    def manifest_meta
      digest = Digest::SHA1.hexdigest(manifest)
      "#{digest} #{manifest.size} #{manifest_name}"
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
        next if File.directory?(src)
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

    # If any path in _paths_ has a sequence of components that matches
    # an equivalent sequence of components (with glob expansion) in
    # our 'Excludes' list, then remove that name from our list.  This
    # filters out CVS directories and whatnot.
    def apply_exclusions paths
      paths.reject do |path|
        excludes.any? do |pattern|
          pattern_components = pattern.split("\\")
          path_components = path.split("/")
          match = false
          if pattern_components[0] == ""
            raise "Can't handle anchored exclude #{pattern}"
          end

          while (!pattern_components.empty? && !path_components.empty? && 
                 pattern_components.length < path_components.length)
            if glob_array_match? pattern_components, path_components
              match = true
              break
            end
            path_components.shift
          end
          
          match
        end
      end
    end

    def glob_array_match? patterns, strings
      patterns.zip(strings).all? do |pattern, string|
        File.fnmatch(pattern, string)
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
    active_stack = []
    active = true
    text.each_line do |line|
      case line
      when /^#\s*define\s+(\w+)\s+(\w*)\s*$/
        defines[$1] = $2 if active
      when /^#\s*if\s+(\w+)\s*$/
        active_stack.push active
        active = active &&
          case preprocessor_expand($1, defines)
          when '0': false 
          when '1': true
          else raise "Can't parse: #{line}" end
      when /^#\s*ifdef\s+(\w+)\s*$/
        active_stack.push active
        active = active && defines.has_key?($1)
      when /^#\s*ifndef\s+(\w+)\s*$/
        active_stack.push active
        active = active && !defines.has_key?($1)
      when /^#\s*else\s*$/
        # If we have a parent if, and it's inactive, we don't actually
        # want to do anything here.
        active = !active if active_stack.empty? || active_stack.last
      when /^#\s*endif(\s+(\w+))?\s*$/
        active = active_stack.pop
      when /^#.*$/
        raise "Unknown preprocessor command: #{line}"
      else
        result << line if active
      end
    end
    raise "Missing #endif" unless active_stack.empty?
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
