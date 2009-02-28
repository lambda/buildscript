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

require 'buildscript/remote_host'
require 'buildscript/manifest_parser'

def usage
  STDERR.puts <<EOF
release-update [--server SERVER] [--stage BUILD-ID | --release TAG]
EOF
  exit 1
end

# We need a class that has a run method, to emulate the build object that
# RemoteHost expects.
class SystemRunner
  def run *args
    command = args.join ' '
    puts ">>> #{command}"
    result = `#{command}`
    unless $? == 0
      STDERR.puts result
      exit $?
    end
    result
  end
end

require 'getoptlong'
require 'buildscript/project_config'

$config = ProjectConfig.new

opts = GetoptLong.new(
  ['--server', GetoptLong::REQUIRED_ARGUMENT],
  ['--stage', GetoptLong::REQUIRED_ARGUMENT],
  ['--release', GetoptLong::REQUIRED_ARGUMENT]
)

opts.each do |opt,arg|
  case opt
    when '--server'
      $server = arg
    when '--stage'
      usage if $release
      $stage = arg
    when '--release'
      usage if $stage
      $release = arg
    else
      usage
  end
end

unless $release || $stage
  usage
end

unless $server
  $server = $config['update.server']
end

$user = $config['update.user']
$tmp = $config['update.tmp']
$buildscript_tmp = $tmp + '/buildscript/'
$update_dir = $config['update.update-dir']
$buildscript_dir = File.dirname(__FILE__) + '/../'
$local_user = ENV['USER']

unless $server && $user && $buildscript_tmp && $update_dir
  STDERR.puts <<EOF
Missing configuration 
Please supply:
EOF
  STDERR.puts '  update.server' unless $server
  STDERR.puts '  update.user' unless $user
  STDERR.puts '  update.buildscript-tmp' unless $buildscript_tmp
  STDERR.puts '  update.update-dir' unless $update_dir
  exit 1
end

$host = RemoteHost.new $server, :runner => SystemRunner.new, :user => $user
$host.upload($buildscript_dir, $buildscript_tmp, :exclude => '.git')

def run_server_script script, *args
  $host.run('ruby', "-I#{$tmp}", 
            "#{$buildscript_tmp}/tools/#{script}",
            *args)
end

def git_tag_build_as build, tag
  sha1 = `git rev-parse --verify 'tags/#{tag}' 2>/dev/null`
  build_tag = "tags/builds/#{build}"
  # If we already have the given tag, assert that it points to the build
  # we have asked for it to point to.
  if $? == 0
    unless sha1 == `git rev-parse --verify '#{build_tag}'`
      raise "Mismatched tag: #{tag} already points to #{sha1}"
    end
  else
    `git rev-parse --verify '#{build_tag}'`
    unless $? == 0
      raise "Could not find build: #{build_tag}"
    end

    system('git', 'tag', tag, build_tag)
  end
end

if $release
  staging_spec = $host.run('cat', $update_dir+"/staging.spec")
  build_id = ManifestParser.parse_spec_file(staging_spec)["Build"]
  git_tag_build_as build_id, $release
  run_server_script('release_update_from_staging.rb', $update_dir, 
                    $local_user, $release)
else
  run_server_script 'stage_update.rb', $update_dir, $local_user, $stage
end
