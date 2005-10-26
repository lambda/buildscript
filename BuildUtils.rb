require 'FileUtils'

# Assorted functions which are helpful for a build.
module BuildUtils
  include FileUtils

  # Give the user 5 seconds to abort the build before performing the
  # described action.
  #
  #   countdown "Deleting /home"
  def countdown description
    STDERR.puts "#{description} in 5 seconds, Control-C to abort."
    (1..5).each do |i|
      STDERR.print "\a" unless i > 3 # Terminal bell.
      STDERR.print "[#{i}] "
      sleep 1
    end
    STDERR.puts
  end
  module_function :countdown
end
