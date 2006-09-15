# Run +cvs+ with the specified arguments.
#   cvs :checkout, 'MyProgram'
def cvs command, *args
  run 'cvs', command.to_s, *args
end

# Build an installer using Inno Setup 4, which must be installed in
# the default location.  For best results, run this from the directory
# containing your application.
#   inno_setup_4 'myprogram.iss'
def inno_setup_4 iss_file, options={}
  defines = (options[:define] || {}).map {|var,value| "-d#{var}=#{value}" }
  run 'c:/Program Files/Inno Setup 4/iscc', iss_file, *defines
end

# ditto, for Inno Setup 5
def inno_setup_5 iss_file, options={}
  defines = (options[:define] || {}).map {|var,value| "-d#{var}=#{value}" }
  run 'c:/Program Files/Inno Setup 5/iscc', iss_file, *defines
end

# Launch Tamale and have it compile all the Scheme scripts in the current
# directory.
def compile_scheme_scripts
  run './Tamale', '-e', '(exit-script)', '.'
end

# Search through _dirs_ for files referenced in an Inno Setup script as
# external install-time resources, and add them to our release list.
def release_installer_support_files iss_file, options, *dirs
  # Figure out what files are available in dirs.  This code is fairly
  # fragile if you're trying to access network drives under Cygwin, which
  # confuse various bits of the Ruby standard library.
  filemap = {}
  dirs.each do |d|
    Dir.new(d).each do |file|
      next if file == '.' or file == '..'
      filemap[file] = "#{d}/#{file}"
    end
  end

  # Search through iss_file, and release any sources that we have.
  File.readlines(iss_file).each do |source|
    if source =~ /^Source: \{src\}\\([^;]+);.*external/
      release filemap[$1], options if filemap[$1]
    end
  end
end
