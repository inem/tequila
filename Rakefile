require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'

require 'test/bench'

desc 'Default: run unit tests.'
task :default => :test

desc 'Test the tequila plugin.'
Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end


desc 'Benchmark'
task :bench do
  TequilaBenchmark.run
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.version = '0.2.0'
    gemspec.name = "Tequila"
    gemspec.summary = "Language for advanced JSON generation"
    gemspec.description = "Language for advanced JSON generation"
    gemspec.email = "eugene.hlyzov@gmail.com"
    gemspec.homepage = "http://github.com/inem/tequila"
    gemspec.authors = ["Eugene Hlyzov", "Ivan Nemytchenko"]
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end
