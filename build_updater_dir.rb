require 'fileutils'
require 'pathname'
require 'child_process'
require 'test/unit'

module ManifestParser
  include FileUtils

  ManifestEntry = Struct.new("ManifestEntry", :hash, :size, :filename)
  
  def parse_manifest text
    result = []
    text.each_line do |line|
      # Note: the next line needs to be a regexp instead of a string, because
      # Ruby special cases a string of a single space to mean "any whitespace"
      # and we just want to break on a single space. 
      arr = line.chomp.split(/ /, 3)
      result << ManifestEntry.new(arr[0], arr[1].to_i, arr[2])
    end
    return result
  end

  module_function :parse_manifest

  def parse_spec_file text
    result = {}
    parts = text.split("\n\n", 2)
    parts[0].each_line do |line|
      key, value = line.chomp.split(': ', 2)
      result[key] = value
    end
    result["MANIFEST"] = parse_manifest(parts[1])
    return result
  end

  module_function :parse_spec_file
end

class UpdateServerInstaller
  include ManifestParser

  def initialize source_path, dest_path
    @source = Pathname.new(source_path)
    @dest = Pathname.new(dest_path)
    @spec_file = @source + "release.spec"
    @spec = parse_spec_file(@spec_file.read)
    @manifest_files = []
    @full_manifest = []
    @spec["MANIFEST"].each do |manifest_entry|
      manifest_file = @source + manifest_entry.filename
      @manifest_files << manifest_file
      manifest = parse_manifest(manifest_file.read)
      @full_manifest += manifest
    end
  end

  def build_update_installer
    build_manifest_dir
    populate_pool
    symlink_staging_spec
  end

  def build_manifest_dir
    @manifest_dir = @dest + "manifests" + @spec["Build"]
    mkdir_p @manifest_dir
    
    @manifest_files.each do |file|
      cp file, @manifest_dir
    end
    cp @spec_file, @manifest_dir    
  end

  def populate_pool
    pool_dir = @dest + "pool"
    mkdir_p pool_dir
    @full_manifest.each do |manifest_entry|
      unless (pool_dir + manifest_entry.hash).exist? 
        cp(@source + manifest_entry.filename, pool_dir + manifest_entry.hash)
      end
    end
  end

  def symlink_staging_spec
    ln_sf((@manifest_dir + "release.spec").expand_path, 
          @dest + "staging.spec")
  end
end
