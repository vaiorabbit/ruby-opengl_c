#require "bundler/gem_tasks"
require 'rake/testtask'
require 'rake/clean'
require 'rbconfig'

DIRNAME = 'opengl_c'
DLNAME  = 'opengl_c_impl'

# "bundle", "so", etc.
DLEXT = RbConfig::CONFIG['DLEXT']

FileUtils.mkpath "lib/#{DIRNAME}/" unless Dir.exists? "lib/#{DIRNAME}/"

# rule to build the extension: this says
# that the extension should be rebuilt
# after any change to the files in ext
file "lib/#{DIRNAME}/#{DLNAME}.#{DLEXT}" =>
Dir.glob("ext/#{DIRNAME}/*{.rb,.c}") do
  Dir.chdir("ext/#{DIRNAME}") do
    # this does essentially the same thing
    # as what RubyGems does
    ruby "extconf.rb", *ARGV.grep(/\A--/)
    sh "make", *ARGV.grep(/\A(?!--)/)
  end
  cp "ext/#{DIRNAME}/#{DLNAME}.#{DLEXT}", "lib/#{DIRNAME}"
end

# make the :test task depend on the shared
# object, so it will be built automatically
# before running the tests
task :test => "lib/#{DIRNAME}/#{DLNAME}.#{DLEXT}"

# use 'rake clean' and 'rake clobber' to
# easily delete generated files
CLEAN.include('ext/**/*{.o,.log,.#{DLEXT}}')
CLEAN.include('ext/**/Makefile')
CLOBBER.include('lib/**/*.#{DLEXT}')

# the same as before
Rake::TestTask.new do |t|
  t.libs << 'test'
end

desc "Run tests"
task :default => :test
