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
# directory.  Automatically manages the TRUST-PRECOMPILED file.
def compile_scheme_scripts
  rm_f 'TRUST-PRECOMPILED'
  # We need to give a real path here, because "." will cause problems for
  # the engine.  And it needs to be a Windows path, not a Cygwin path!
  run './Tamale', '-e', '(exit-script)', absolute_path(pwd)
  run 'touch', 'TRUST-PRECOMPILED'
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

# Parse the iss_file, and generate the manifest files for this release.
# Include update_url in the manifest files, so that the installed program
# knows where to find updates.
def generate_manifest_files iss_file, update_url
  iss = InnoSetup::SourceFile.new(iss_file, 'CD_INSTALLER' => 1)
  iss.components.each do |name, component|
    next unless component.includes_manifest?
    manifest = component.manifest
    # TODO - We need to include *.iss file's directory when creating this file.
    File.open(component.manifest_name, 'w') {|f| f.write(manifest) }
  end
  File.open("release.spec", 'w') do |f| 
    f.write(iss.spec_file("Build" => release_id || "DIRTY", 
                          "Update-URL" => update_url))
  end
end

# Copy files to update server, and put them in the right places for us to
# update from. 
# TODO - could probably still use some refactoring, as could MANIFEST section
# TODO - don't copy .svn directories
def upload_files_for_updater(update_ssh_host, update_path,
                             update_temp_path, program_unix_name)
                             
  server = remote_host(update_ssh_host)
  program_temp = "#{update_temp_path}/#{program_unix_name}"
  buildscript_temp = "#{update_temp_path}/buildscript"
  
  server.run('rm', '-rf', program_temp, buildscript_temp)
  server.upload('./', program_temp, :exclude => '.svn')
  server.upload("#{buildscript_source_dir}/", buildscript_temp,
                :exclude => '.svn')
  server.run('ruby', "-I#{buildscript_temp}", 
             "#{buildscript_temp}/build_update_server.rb",
             program_temp, update_path)
  server.run('rm', '-rf', program_temp, buildscript_temp)
end
