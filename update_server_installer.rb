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

require 'fileutils'
require 'pathname'
require 'time'
require 'buildscript/child_process'
require 'buildscript/manifest_parser'

class UpdateServer
  include ManifestParser

  def UpdateServer.parse_log str
    lines = []
    str.each_line do |line|
      fields = line.split(" ", 5)
      lines += [{ :before => fields[0], :after => fields[1], :user => fields[2],
                 :time => fields[3], :notes => fields[4] && fields[4].chomp }]
    end
    lines
  end
  
  def initialize updater_dir, opts = { }
    @root = Pathname.new(updater_dir)
    @user = opts[:user] or ENV["USER"]
  end

  def release_from_staging notes=""
    update_spec_file "staging.spec", "release.spec", notes
  end

  def canonical_path file
    if file.symlink?
      file = file.readlink
    end
    
    file.expand_path
  end

  def update_spec_file src, dst, notes=""
    src_file = @root + src
    src_sig = @root + "#{src}.sig"
    dst_file = @root + dst
    dst_sig = @root + "#{dst}.sig"

    log = @root + "#{dst}.log"
    
    if dst_file.exist?
      old_build = parse_spec_file(dst_file.read)["Build"]
    else
      old_build = "<null>"
    end

    new_build = parse_spec_file(src_file.read)["Build"]
    time = Time.now.xmlschema # Time in YYYY-MM-DDTHH:MM:SS[+-]TZ format

    File.open(log, 'a') do |file|
      file.puts "#{old_build} #{new_build} #{@user} #{time} #{notes}"
    end

    rm dst_file if dst_file.exist?
    ln_s canonical_path(src_file), dst_file
    rm dst_sig if dst_sig.exist?
    ln_s canonical_path(src_sig), dst_sig if src_sig.exist?
  end
end

class UpdateServerInstaller
  include ManifestParser

  def initialize source_path, dest_path, opts = { }
    @source = Pathname.new(source_path)
    @dest = Pathname.new(dest_path)
    @spec_file = @source + "release.spec"
    @sig_file = @source + "release.spec.sig"
    @spec = parse_spec_file(@spec_file.read)
    @manifest_files = []
    @full_manifest = []
    @spec["MANIFEST"].each do |manifest_entry|
      manifest_file = @source + manifest_entry.filename
      @manifest_files << manifest_file
      manifest = parse_manifest(manifest_file.read)
      @full_manifest += manifest
    end
    @user = opts[:user]
  end

  def build_update_installer
    build_manifest_dir
    populate_pool
    symlink_staging_spec
  end

  def build_manifest_dir
    @manifest_dir = @dest + "manifests" + @spec["Build"]
    mkdir_p @manifest_dir

    files_to_copy = @manifest_files + [@spec_file, @sig_file]
    
    files_to_copy.each do |file|
      cp file, @manifest_dir
      chmod 0444, @manifest_dir+file.basename
    end

    chmod 0555, @manifest_dir
  end

  def populate_pool
    pool_dir = @dest + "pool"
    mkdir_p pool_dir
    @full_manifest.each do |manifest_entry|
      unless (pool_dir + manifest_entry.hash).exist? 
        dest_file = pool_dir + manifest_entry.hash
        cp(@source + manifest_entry.filename, dest_file)
        chmod 0444, dest_file
      end
    end
  end

  def symlink_staging_spec
    server = UpdateServer.new(@dest, :user => @user)
    release_spec = (@manifest_dir+"release.spec").relative_path_from(@dest)

    # Path names are relative to @dest
    server.update_spec_file(release_spec, "staging.spec")
  end
end
