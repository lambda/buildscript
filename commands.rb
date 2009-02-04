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

# Run +cvs+ with the specified arguments.
#   cvs :checkout, 'MyProgram'
def cvs command, *args
  run 'cvs', command.to_s, *args
end

# Run +svn+ with the specified arguments.
#   svn :checkout, 'MyProgram'
def svn command, *args
  run 'svn', command.to_s, *args
end

# Run +git+ with the specified arguments.
#   git :clone, 'git://imlsrc.dartmouth.edu/program'
def git command, *args
  run 'git', command.to_s, *args
end

# Check out a project from SVN, and tag it with the release_id of this
# build.  This will always checkout from /trunk, and tag to 
# /tags/builds/#{release_id}
def svn_co_and_tag working_copy, svn_base, release_id
  svn :co, "#{svn_base}/trunk", working_copy
  svn(:copy, '-m', "Tagging build #{release_id}", working_copy, 
      "#{svn_base}/tags/builds/#{release_id}")
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

# Launch Halyard and have it compile all the Scheme scripts in the current
# directory.  Automatically manages the TRUST-PRECOMPILED file.
def compile_scheme_scripts
  rm_f 'TRUST-PRECOMPILED'
  # We need to give a real path here, because "." will cause problems for
  # the engine.  And it needs to be a Windows path, not a Cygwin path!
  # We need to be in command line mode, not runtime mode, so we will write
  # out our file count for our progress bar.
  run './engine/win32/Halyard', '-c', '(exit-script)', absolute_path(pwd)
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
  iss = InnoSetup::SourceFile.new(iss_file, Dir.getwd, 'CD_INSTALLER' => 1)
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
  sign_file_with_gpg 'release.spec'
end

# Copy files to update server, and put them in the right places for us to
# update from. 
# TODO - could probably still use some refactoring, as could MANIFEST section
# TODO - don't copy .svn directories
def upload_files_for_updater(update_ssh_host, update_ssh_user, update_path,
                             update_temp_path, program_unix_name)
                             
  server = remote_host(update_ssh_host, :user => update_ssh_user)
  program_temp = "#{update_temp_path}/#{program_unix_name}"
  buildscript_temp = "#{update_temp_path}/buildscript"
  
  server.upload('./', program_temp, :exclude => '.svn')
  server.upload("#{buildscript_source_dir}/", buildscript_temp,
                :exclude => '.svn')
  server.run('chmod', '-R', 'a+r', program_temp, buildscript_temp)
  server.run('chmod', '-R', 'ug+wX', program_temp, buildscript_temp)
  server.run('ruby', "-I#{update_temp_path}", 
             "#{buildscript_temp}/build_update_server.rb",
             program_temp, update_path)
end

# Create a tarball of directory dir, named dir.tar.gz by default, and
# mark it for release, excluding any version control files as well as
# any files explicitly excluded.
def make_tarball dir, options={}
  options[:filename] = options[:filename] || "#{dir}.tar.gz"
  make_tarball_from_files [dir], options
end

def exclude_each exclude
  if (exclude)
    if (exclude.is_a? Array)
      exclude.each do |glob|
        yield glob
      end
    else
      yield exclude
    end
  end
end


# Create a tarball of the given files, and mark it for release,
# excluding any version control files as well as any files explicitly
# excluded.
def make_tarball_from_files files, options={}
  tarball = options[:filename]
  args = ['czf', tarball, '--exclude-vcs']
  exclude_each options[:exclude] do |exclude|
    args.push '--exclude', exclude
  end
  args.concat files
  run 'tar', *args
  release tarball, :cd => 1
end

# Create a ZIP file of directory dir, named dir.zip by default, and
# mark it for release, excluding any version control files as well as
# any files explicitly excluded.
#
# Note that excludes work a bit differently for zip; you need to pass
# a glob that matches the full path, excluding a directory does not
# actually exclude the files within it, you must exclude them with a
# glob as well, and in order to exclude a directory, you need to
# include the trailing slash.
def make_zipfile dir, options={}
  zipfile = options[:filename] || "#{dir}.zip"
  excludes = ['-x', '*/.git/*', '-x', '*/.gitignore']
  exclude_each options[:excludes] do |exclude|
    excludes.push '-x', exclude
  end
  run 'zip', '-r', zipfile, dir, *excludes
  release zipfile, :cd => 1
end
