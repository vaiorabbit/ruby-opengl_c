require 'rexml/document'

def generate_ext_command( out )

  doc = REXML::Document.new(open("./gl.xml"))

  # Extract extension command
  gl_ext_name_to_commands_map = {}
  REXML::XPath.each(doc, 'registry/extensions/extension') do |extension_tag|
    if extension_tag.attribute('supported').value.split('|').include?( 'gl' ) # ignoring "gles1", "glcore", etc.

      # Extension name (GL_NV_fence, etc.)
      ext_name =  extension_tag.attribute('name').value

      # Extension commands (glGenFencesNV, etc.)
      ext_command_map = []
      REXML::XPath.each(extension_tag, 'require/command') do |tag|
        ext_command_map << tag.attribute('name').value
      end

      # Create mapping table ("GL_NV_fence" => {"glGenFencesNV" => ...}, etc.)
      gl_ext_name_to_commands_map[ext_name] = ext_command_map
    end
  end

  # Output
  out.puts "# opengl-bindings"
  out.puts "# * http://rubygems.org/gems/opengl-bindings"
  out.puts "# * http://github.com/vaiorabbit/ruby-opengl"
  out.puts "#"
  out.puts "# [NOTICE] This is an automatically generated file."
  out.puts ""
  out.puts "module OpenGLExt"
  out.puts ""
  gl_ext_name_to_commands_map.each_pair do |ext_name, ext_commands|

    # def self.get_ext_command_XXXX; ... ;end
    out.puts "  def self.get_ext_command_#{ext_name}"
    out.puts "    ["
    ext_commands.each do |api|
    out.puts "      '#{api}',"
    end
    out.puts "    ]"
    out.puts "  end # self.get_ext_command_#{ext_name}"
    out.puts "\n"
  end
  out.puts "end"

end


if $0 == __FILE__
  generate_ext_command( $stdout )
end
