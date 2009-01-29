# Type 'rake -H' for help, or 'rake -T' for a list of tasks.
require 'rake/testtask'

SRC = FileList['*.rb']
DOC_SRC = SRC.select {|f| !(f =~ /^Test/) }

task :default => [:test]

desc "Run our test suites"
Rake::TestTask.new(:test) do |t|
  # All of our files are written assuming that buildscript is a
  # subdirectory of something in our lib path, so we need to add
  # .. to our lib path to make everything work.
  t.libs << '..'
  t.pattern = '*_test.rb'
  t.verbose = true
end

desc "Make a nice manual"
task :doc do |t|
  sh 'rdoc', *DOC_SRC
end
