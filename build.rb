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

require 'forwardable'
require 'pathname'
require 'digest/sha1'

require 'buildscript/child_process'
require 'buildscript/build_utils'
require 'buildscript/report'
require 'buildscript/code_signing'

# Implements a mini-language for describing one-button builds.
class Build
  include BuildUtils
  extend Forwardable

  # Holds information about a path which will be included in our release.
  ReleaseInfo = Struct.new(:path, :options) #:nodoc:

  # The directory in which this program will be built from scratch.
  attr_reader :build_dir

  # The directory in which all releases of the program can be found.  Not
  # present for dirty builds.
  attr_reader :release_dir

  # A name of the form 'YYYY-MM-DD-X', where _X_ is a letter.  Not present
  # for dirty builds.
  attr_reader :release_id

  # The subdirectory of #release_dir which will be used for this build.
  # Not present for dirty builds.
  def release_subdir
    return nil if dirty?
    "#{release_dir}/#{release_id}"
  end

  # Returns true if the build is "dirty", that is, not checked out from
  # scratch.
  def dirty?() @dirty end

  # Should we sign this build?
  def sign?() @sign end

  # Returns true if the build is in release mode.  A "release" build is one
  # which is being made available to the public; other builds are assumed
  # to be purely internal.  Typically, higher layers will upload builds to
  # a different server if this function returns true.
  def release?() @release end
  
  # Returns true once #finish has been called.
  def finished?() @finished end

  # Delegate _run_ to our @report member variable.  See Report for more
  # information.
  def_delegators :@report, :run

  # Create a new Build. Options include:
  #
  # +build_dir+:: The directory to build into.  Will be deleted.
  # +release_dir+:: The directory in which to put the release.  A new
  #                 subdirectory will be created for each release.
  # +silent+:: Don't produce any output.  Useful for test suites.
  # +dirty_build+:: If true, don't delete the build directory.
  def initialize options
    @build_dir = options[:build_dir]
    @silent = options[:silent]
    @enabled_headings = options[:enabled_headings]
    @dirty = options[:dirty_build] || (@enabled_headings && true)
    @release = options[:release_build] || false
    @sign = options[:sign] || @release # Always sign release builds.
    @signing_key = options[:signing_key]
    @release_dir = options[:release_dir] unless dirty?
    @finished = false
    @release_infos = []

    # Set up code signing first, because it has an interactive prompt.
    initialize_code_signing @signing_key if sign?

    # Delete our build directory if it exists.
    if File.exists?(build_dir) && !dirty?
      countdown "Deleting #{build_dir}"
      rm_rf build_dir
    end
    mkdir_p build_dir
    
    # Create a new report for this build.
    @report = Report.new(:dir => build_dir, :silent => @silent)
    release @report.path

    # Set up our release directory.
    make_release_dir unless dirty?
  end

  # If code signing is enabled, sign the specified file.
  def sign_file path, description=nil, description_url=nil
    return unless sign?
    CodeSigning::sign_file(path,
                           :key_file => @signing_key_path,
                           :password => @signing_key_password,
                           :description => description,
                           :description_url => description_url)
  end

  # If code signing is enabled, sign the specified file with GnuPG.
  def sign_file_with_gpg path
    return unless sign?
    CodeSigning::sign_file_with_gpg(path,
                                    :password => @signing_key_password,
                                    :homedir =>
                                      File.dirname(@signing_key_path))
  end

  # Indicate that a file or directory should be included in our release.
  #
  # +subdir+:: Copy _path_ into the specified subdirectory of #release_subdir.
  # +filtered+:: Only copy files matching a regular expression.  _path_ must
  #              be a directory.
  # +cd+:: Place a copy of this file on the specified CD.
  # +cd_only+:: Do not put a copy of this file in the upload directory.
  #
  # The following code releases a directory "Text Files/Extras" containing
  # files with the extension +txt+.
  #
  #   release('Text Files', :cd => 2, :subdir => 'Extras',
  #           :filtered => /\.txt$/)
  def release path, options={}
    assert !finished?
    @release_infos << ReleaseInfo.new(absolute_path(path), options)
  end
  
  # Print a heading, and execute the corresponding body of code, if this 
  # section is not disabled.  This uses Report when it's available, and 
  # +$stdout+ otherwise.
  def heading str, options={}
    # We want to make sure that every named heading has an associated block, 
    # because the only reason to name a heading is to be able to disable the 
    # associated block.
    assert block_given? if options[:name]
    if should_execute_section?(options[:name])
      if @report && !@report.closed?
        @report.heading str
      else
        puts ">>>>> #{str}" unless @silent
      end
      yield if block_given?
    end
  end

  # Finish the build, and close our report files.
  def finish
    assert !finished?
    cds = @release_infos.collect {|i| i.options[:cd]}.compact.sort.uniq
    cds.each {|n| make_cd n}
    @report.close
    upload_release_files
    @finished = true
  end

  # Determine the command line options to hide files on a given CD
  def mkisofs_hidden cd
    args = []
    @release_infos.each do |info|
      if info.options[:cd] == cd && info.options[:hidden]
        args.push '-hidden'
        base = Pathname.new(info.path).basename.to_s
        name = if info.options[:subdir]
                 "#{info.options[:subdir]}/#{base}"
               else
                 base
               end
        args.push name
      end
    end
    args
  end

  private

  # Set up our code signing environment.
  #
  # TODO - Figure out how to check the validity of the password now, up
  # front.
  def initialize_code_signing key_file
    # Do we support hidden passwords?
    unless CodeSigning::HIDDEN_PASSWORDS
      raise "Must install Ruby termios gem to sign code"
    end
    
    # Get the private key and the password to unlock it.
    @signing_key_path = CodeSigning::find_key(@signing_key)
    print "Password for #{@signing_key_path} (type carefully!): "
    @signing_key_password = CodeSigning::gets_secret

    # TODO - Temporary code to print a hexdigest of the password so that
    # the person running the build has a chance of detecting bad passwords.
    digest = Digest::SHA1.hexdigest(@signing_key_password)
    puts "\n    PLEASE CONFIRM PASSWORD DIGEST:\n\n    #{digest}\n\n"
  end

  # Should we execute a section with a given name? True if we have a name 
  # and it's on the list of sections to execute, we don't have a name, or 
  # we don't have a list of sections to execute, which means execute all by
  # default. 
  def should_execute_section? name
    !name || !@enabled_headings || @enabled_headings.include?(name)
  end

  # Create a directory to hold our release files.
  def make_release_dir
    mkdir_p release_dir
    for letter in 'A'..'Z'
      candidate = Time.now.strftime("%Y-%m-%d-#{letter}")
      dir = "#{release_dir}/#{candidate}"
      unless File.directory? dir
        mkdir dir
        @release_id = candidate
        break
      end
    end
    unless @release_id
      raise RuntimeError, "Can't make 27 builds in one day", caller
    end    
  end

  # Make a CD image.
  def make_cd number
    # Create a directory of files to place on the CD.
    heading "Gathering files for CD #{number}"
    cd_dir = "#{build_dir}/cd#{number}"
    mkdir_p cd_dir
    @release_infos.each do |info|
      cp_release_files(info, cd_dir) if info.options[:cd] == number
    end
    
    # Build an ISO.
    heading "Building ISO for CD #{number}"
    cd cd_dir do
      iso_file = "../CD #{number}.iso"
      extra_args = mkisofs_hidden(number) + ['.']
      run 'mkisofs', '-J', '-R', '-o', iso_file, *extra_args
      release iso_file
    end
    rm_r cd_dir
  end

  # Upload all files marked for release.
  def upload_release_files
    # Print an appropriate heading
    if dirty?
      heading "Pretending to release files"
    else
      heading "Releasing files to #{release_subdir}."
    end

    # Release the individual files.
    @release_infos.each do |info|
      next if info.options[:cd_only]
      puts info.path unless @silent      
      cp_release_files info, release_subdir unless dirty?
    end
  end

  # Copy the files specified by a ReleaseInfo object to the specified
  # destination directory.
  def cp_release_files info, dst
    subdir = info.options[:subdir]
    dst = "#{dst}/#{subdir}" if subdir
    mkdir_p dst
    cp_filtered info.path, dst, info.options[:filter]
  end
end
