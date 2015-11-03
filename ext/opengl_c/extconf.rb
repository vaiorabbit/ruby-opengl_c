require 'mkmf'

if RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin/
  $LOCAL_LIBS << "-lopengl32"
end

create_makefile('opengl_c/opengl_c_impl')
