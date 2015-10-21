require_relative 'opengl_c/opengl_c_impl'
require_relative 'opengl_platform'
require 'fiddle'

module OpenGL
  Impl = "Binary" # .dll/.so/.dylib

  set_fiddle_pointer_module(Fiddle::Pointer)
end
