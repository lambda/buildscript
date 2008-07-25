require 'buildscript/update_server_installer'

installer = UpdateServerInstaller.new(ARGV[0], ARGV[1])
installer.build_update_installer
