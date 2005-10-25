SRC = FileList['*.rb']
DOC_SRC = SRC.select {|f| !(f =~ /^Test/) }

task :default => [:test]

# Ran 'rake test' to run our test suites.
task :test do |t|
  sh 'ruby', 'TestAll.rb'
end

# Run 'rake doc' to make a nice manual.
task :doc do |t|
  sh 'rdoc', *DOC_SRC
end
