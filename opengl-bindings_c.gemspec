# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |gem|
  gem.name          = "opengl-bindings_c"
  gem.version       = "0.5.0"
  gem.authors       = ["vaiorabbit"]
  gem.email         = ["vaiorabbit@gmail.com"]
  gem.summary       = %q{Ruby OpenGL Bindings (C Edition)}
  gem.homepage      = "https://github.com/vaiorabbit/ruby-opengl_c"
  gem.require_paths = ["lib"]
  gem.license       = "zlib/libpng"

  gem.extensions    = ['ext/opengl_c/extconf.rb']
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }

  gem.description   = <<-DESC
Ruby bindings for OpenGL - 4.5, OpenGL ES - 3.2 and all extensions using Fiddle (For MRI >= 2.0.0). GLFW/GLUT/GLU bindings are also available.
  DESC

  gem.required_ruby_version = '>= 2.0.0'

  gem.files = Dir.glob("lib/*.rb") +
              Dir.glob("ext/opengl_c/*.{c,h,inc,rb}") +
              ["README.md", "LICENSE.txt", "ChangeLog"] +
              ["sample/simple.rb"]
end
