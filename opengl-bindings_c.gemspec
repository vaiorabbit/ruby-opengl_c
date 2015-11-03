# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "opengl-bindings_c"
  gem.version       = "0.5.1.pre4"
  gem.authors       = ["vaiorabbit"]
  gem.email         = ["vaiorabbit@gmail.com"]
  gem.summary       = %q{Ruby OpenGL Bindings (C Edition)}
  gem.homepage      = "https://github.com/vaiorabbit/ruby-opengl_c"
  gem.require_paths = ["lib"]
  gem.license       = "zlib/libpng"

  gem.extensions    = ['ext/opengl_c/extconf.rb']
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }

  gem.description   = <<-DESC
Replaces pure-ruby OpenGL API calls in opengl-bindings ( https://github.com/vaiorabbit/ruby-opengl ) with native C function calls.
Notice: This library provides native extension. You must setup development environment (or DevKit) before installation.
  DESC

  gem.required_ruby_version = '>= 2.2.0'

  gem.add_runtime_dependency 'opengl-bindings', '~> 1.5', '>= 1.5.1'

  gem.files = Dir.glob("lib/*.rb") +
              Dir.glob("ext/opengl_c/*.{c,h,inc,rb}") +
              ["README.md", "LICENSE.txt", "ChangeLog"]
end
