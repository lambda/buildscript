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

require 'rubygems'
gem 'termios'
require 'termios'
require 'buildscript/child_process'

# Support for singing code using Authenticode and GPG.  This only works
# with Cygwin Ruby under Windows, AFAIK.
#
# TODO - Some test suites would be nice.
module CodeSigning

  #========================================================================
  #  Password prompting
  #========================================================================
  
  # This section of termios-related code is taken verbatim from one of my
  # personal projects, and I hereby place it into the public domain.
  # -Eric Kidd, 14 Nov 2007
  begin
    require 'termios'
    
    # Code for reading a password from the console without echo.  Adapted from
    # the termios gem documentation, and apparently available at
    # [ruby-list:15968].  This code doesn't stand a chance of working on
    # Windows, unfortunately.
    def self.gets_secret
      oldt = Termios.tcgetattr($stdin)
      newt = oldt.dup
      newt.lflag &= ~Termios::ECHO
      Termios.tcsetattr($stdin, Termios::TCSANOW, newt)
      result = $stdin.gets
      Termios.tcsetattr($stdin, Termios::TCSANOW, oldt)
      print "\n"
      result.chomp
    end
    HIDDEN_PASSWORDS = true
  rescue MissingSourceFile
    def self.gets_secret
      STDIN.gets.chomp
    end
    HIDDEN_PASSWORDS = false
  end


  #========================================================================
  #  Code signing
  #========================================================================

  # The default timestamp service.  Using this allows our signatures to
  # outlast our singing keys.
  DEFAULT_TIMESTAMP_URL = 'http://timestamp.verisign.com/scripts/timstamp.dll'

  # Sign a file with the specified key and other parameters.
  def self.sign_file file, options
    key_file        = options[:key_file] || raise('Must specify key_file')
    password        = options[:password] || raise('Must specify password')
    description     = options[:description]
    description_url = options[:description_url]
    timestamp_url   = options[:timestamp_url] || DEFAULT_TIMESTAMP_URL
    
    # signtool /f <key_file> /p <pass> /d <desc> /du <desc_url>
    #          /t <timestamp_url>
    # Returns 0 on success, 1 on failure and 2 on warning
    flags  = ['/q', '/f', key_file, '/p', password, '/t', timestamp_url]
    flags += ['/d',  description]     if description
    flags += ['/du', description_url] if description
    
    # Call this using 'system', so that we don't display our password
    # to the console.
    system 'signtool', 'sign', *(flags + [file]) or
      raise 'Error running signtool'
  end

  # Sign a file using GPG.  This will create a detached *.sig file.
  # Keyrings are assumed to be found in ':homedir', and the default key
  # will be used.
  def self.sign_file_with_gpg file, options
    homedir = options[:homedir] || raise('Must specify homedir')
    password = options[:password] || raise('Must specify password')

    args = ["#{homedir}/gpg", '--homedir', homedir, '--batch', '--no-tty',
            '--yes', '--passphrase-fd', '0', '--detach-sign', file]

    # TODO - This bears a close relation to the code in report.rb, but we
    # need to pass in a password.  Maybe we could combine the two routines
    # sensibly?
    ChildProcess.exec(:combine_output => true, *args) do |child|
      child.in.puts password
      until child.out.eof?
        puts child.out.gets
      end
      unless child.wait.success?
        raise "Error running gpg"
      end
    end
  end

  # Look for a specified *.pfx keyfile on the root level of any removable
  # drives.  The theory here is that our *.pfx key lives on a USB stick.
  def self.find_key name
    for drive in 'D'..'L'
      candidate = "#{drive}:/#{name}.pfx"
      if File.exists?(candidate)
        return candidate
      end
    end
    raise "Cannot find key file '#{name}.pfx' on any removable drive"
  end
end
