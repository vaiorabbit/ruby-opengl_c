require_relative 'c_generate_common'

module GLExtRubyEnumCodeGenerator

  def self.generate_ext_enum( out )
    doc = REXML::Document.new(open("./gl.xml"))

    # Collect all enum
    gl_all_enum_map = {}
    REXML::XPath.each(doc, 'registry/enums/enum') do |enum_tag|
      # # check alias
      # alias_attr = enum_tag['alias']
      # next if alias_attr != nil

      gl_all_enum_map[enum_tag.attribute('name').value] = enum_tag.attribute('value').value
    end

    # Extract enum
    gl_ext_name_to_enums_map = {}
    REXML::XPath.each(doc, 'registry/extensions/extension') do |extension_tag|
      if extension_tag.attribute('supported').value.split('|').include?( 'gl' ) # ignoring "gles1", "glcore", etc.

        # Extension name (GL_NV_fence, etc.)
        ext_name =  extension_tag.attribute('name').value

        # Extension enums (GL_FENCE_STATUS_NV, etc.)
        ext_enum_map = {}
        REXML::XPath.each(extension_tag, 'require/enum') do |tag|
          ext_enum_map[tag.attribute('name').value] = gl_all_enum_map[tag.attribute('name').value]
        end

        # Create mapping table ("GL_NV_fence" => {"GL_FENCE_STATUS_NV" => 0x84F3}, etc.)
        gl_ext_name_to_enums_map[ext_name] = ext_enum_map

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
    gl_ext_name_to_enums_map.each_pair do |ext_name, ext_enums|
      # def self.get_ext_enum_XXXX; ... ;end
      out.print "  def self.get_ext_enum_#{ext_name}\n"
      out.puts  "    ["
      ext_enums.each do |enums|
        out.puts "      '#{enums[0]}',"
      end
      out.puts  "    ]"
      out.print "  end # self.get_ext_enum_#{ext_name}\n\n"
    end
    out.puts "end"
  end

end

if __FILE__ == $0
  GLExtRubyEnumCodeGenerator.generate_ext_enum( $stdout )
end
