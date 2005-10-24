SRC = FileList['*.rb']

task :default => [:test]

# Ran 'rake test' to run our test suites.
task :test do |t|
  sh 'ruby', 'TestChildProcess.rb'
end

# Run 'rake doc' to make a nice manual.
task :doc do |t|
  sh 'rdoc', *SRC
end
