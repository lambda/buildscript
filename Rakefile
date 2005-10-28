# Type 'rake -H' for help.

SRC = FileList['*.rb']
DOC_SRC = SRC.select {|f| !(f =~ /^Test/) }

task :default => [:test]

desc "Run our test suites"
task :test do |t|
  sh 'ruby', 'TestAll.rb'
end

desc "Make a nice manual"
task :doc do |t|
  sh 'rdoc', *DOC_SRC
end
