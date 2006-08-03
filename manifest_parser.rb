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
