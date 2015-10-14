require_relative 'opengl_c'
require_relative 'opengl_ext_c_impl'
require_relative 'opengl_ext_command'
require_relative 'opengl_ext_enum'

module OpenGL

  def self.check_extension( ext_name )
    version_number = glGetString(GL_VERSION).split(/\./)
    if version_number[0].to_i >= 3
      # glGetString(GL_EXTENSIONS) was deprecated in OpenGL 3.0
      # Ref.: http://sourceforge.net/p/glew/bugs/120/
      extensions_count_buf = ' ' * 4
      glGetIntegerv( GL_NUM_EXTENSIONS, extensions_count_buf )
      extensions_count = extensions_count_buf.unpack('L')[0]
      extensions_count.times do |i|
        supported_ext_name = glGetStringi( GL_EXTENSIONS, i )
        return true if ext_name == supported_ext_name
      end
      return false
    else
      ext_strings = glGetString(GL_EXTENSIONS).split(/ /)
      return ext_strings.include? ext_name
    end
  end

  def self.setup_extension( ext_name, skip_check: false )
    # dummy
  end

  def self.setup_extension_all( skip_check: false )
    # dummy
  end

  def self.get_extension_enum_symbols( ext_name )
    get_ext_enum = "get_ext_enum_#{ext_name}".to_sym
    OpenGLExt.send( get_ext_enum )
  end

  def self.get_extension_command_symbols( ext_name )
    get_ext_command = "get_ext_command_#{ext_name}".to_sym
    OpenGLExt.send( get_ext_command )
  end

end
