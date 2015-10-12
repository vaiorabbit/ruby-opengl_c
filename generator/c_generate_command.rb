require_relative 'c_generate_common'

module GLCodeGenerator

  def self.generate_command( out )

    doc = REXML::Document.new(open("./gl.xml"))

    gl_std_cmd_map  = build_std_commands_map(doc)
    gl_std_enum_map = build_std_enums_map(doc)

    # Output
    out.puts <<-PROLOGUE
/* opengl-bindings
 * * http://rubygems.org/gems/opengl-bindings_c
 * * http://github.com/vaiorabbit/ruby-opengl_c
 *
 * [NOTICE] This is an automatically generated file.
 */
PROLOGUE
    generate_entry_point(out, gl_std_cmd_map)
    generate_function_call(out, gl_std_cmd_map, gl_std_enum_map)

  end

  def self.build_std_commands_map(doc)
    # Collect all command
    gl_all_cmd_map = {}
    REXML::XPath.each(doc,'registry/commands/command') do |cmd_tag|
      # check alias
      alias_tag = cmd_tag.get_elements('alias')
      next if alias_tag.length != 0 # skips glActiveTextureARB (alias of glActiveTexture), etc.

      map_entry = GLCommandMapEntry.new

      proto_tag = cmd_tag.get_elements('proto').first

      # Patterns of contents inside '<proto>...</proto>'
      # * void <name>glBegin</name>
      # * <ptype>GLboolean</ptype> <name>glIsEnabled</name>
      # * const <ptype>GLubyte</ptype> *<name>glGetStringi</name>

      map_entry.api_name = proto_tag.get_elements('name').first.text
      proto_ptype = proto_tag.get_elements('ptype').first
      proto_residue = proto_tag.texts.join(" ")
      if proto_residue =~ /const/
        proto_residue.slice!("const")
        proto_residue.strip!
      end
      map_entry.ret_name = if proto_ptype != nil
                             proto_ptype.text.strip
                           else
                             proto_tag.text.strip
                           end
      map_entry.ret_name << ' *' if proto_residue =~ /\*/

      # Patterns of contents inside '<param>...</param>':
      # * <ptype>GLenum</ptype> <name>mode</name> (glBegin)
      # * <ptype>GLuint</ptype> <name>baseAndCount</name>[2] (glPathGlyphIndexRangeNV)
      # * <ptype>GLfloat</ptype> *<name>data</name> (glGetFloatv) : param_tag.texts == [" *"]
      # * const <ptype>GLfloat</ptype> *<name>params</name> (glMaterialfv) : param_tag.texts == ["const ", " *"]
      # * const void *<name>data</name> (glBufferData) : param_tag.texts == ["const void *"]
      map_entry.type_names = []
      map_entry.var_names = []
      REXML::XPath.each(cmd_tag, 'param') do |param_tag|
        var_name = param_tag.get_elements('name').first.text.strip
        param_ptype = param_tag.get_elements('ptype').first
        param_residue = param_tag.texts.join(" ")
        if param_residue =~ /const/
          param_residue.slice!("const")
          param_residue.strip!
        end
        type_name = if param_ptype != nil
                      param_ptype.text.strip
                    else
                      param_tag.text.strip
                    end
        type_name << ' *' if param_residue =~ /\*/ || param_residue =~/\[.+\]/
        map_entry.type_names << type_name
        map_entry.var_names << var_name
      end

      gl_all_cmd_map[map_entry.api_name] = map_entry
    end

    # Extract standard command
    gl_std_cmd_map = {}
    REXML::XPath.each(doc, 'registry/feature') do |feature_tag|
      if "gl" == feature_tag.attribute('api').value

        # OpenGL Standard enums
        REXML::XPath.each(feature_tag, 'require/command') do |tag|
          gl_std_cmd_map[tag.attribute('name').value] = gl_all_cmd_map[tag.attribute('name').value]
        end

      end
    end

    return gl_std_cmd_map

  end

  def self.build_std_enums_map(doc)
    # Collect all enum
    gl_all_enum_map = {}
    REXML::XPath.each(doc, 'registry/enums/enum') do |enum_tag|
      # # check alias
      # alias_attr = enum_tag['alias']
      # next if alias_attr != nil

      gl_all_enum_map[enum_tag.attribute('name').value] = enum_tag.attribute('value').value
    end

    # Extract standard enum
    gl_std_enum_map = {}
    REXML::XPath.each(doc, 'registry/feature') do |feature_tag|
      if "gl" == feature_tag.attribute('api').value

        # OpenGL Standard enums
        REXML::XPath.each(feature_tag, 'require/enum') do |tag|
          gl_std_enum_map[tag.attribute('name').value] = gl_all_enum_map[tag.attribute('name').value]
        end

      end
    end

    return gl_std_enum_map

  end

  def self.generate_entry_point(out, gl_std_cmd_map)

    # Typedef
    gl_std_cmd_map.each_pair do |api, map_entry|
      typedef_line = "typedef "

      arg_names = []
      map_entry.type_names.each do |t|
        resolved_gl_type = OpenGL::GL_TYPE_MAP[t]
        is_array = t.include?( "[" )
        is_ptr = t.end_with?( '*' )
        if !is_ptr && !is_array && resolved_gl_type == nil
          $stderr.puts "[ERROR] ruby-opengl generator script 'generate_command.rb' : Unknown type '#{t}' detected. Exiting..."
          exit
        end
        arg_names << ((is_ptr || is_array) ? 'void*' : resolved_gl_type)
      end

      # Return value
      is_ptr = map_entry.ret_name.end_with?( '*' )
      typedef_line += "#{is_ptr ? 'void*' : OpenGL::GL_TYPE_MAP[map_entry.ret_name]} "
      # Function pointer
      typedef_line += "(* ROGL_PFN#{api.upcase}PROC) ("
      # Arguments
      if arg_names.length == 0
        typedef_line += "void"
      else
        arg_names.each_with_index do |a, i|
          typedef_line += "#{a} #{map_entry.var_names[i]}%s"%[(i < arg_names.length-1 ? ", " : "")]
        end
      end
      typedef_line += ");"

      out.puts typedef_line
    end

    out.puts ""

    # Entry points
    gl_std_cmd_map.each_pair do |api, map_entry|
      out.puts "static ROGL_PFN#{api.upcase}PROC rogl_pfn_#{api} = NULL;"
    end
  end


  def self.generate_function_call(out, gl_std_cmd_map, gl_std_enum_map)

    out.puts ""

    # Function call
    gl_std_cmd_map.each_pair do |api, map_entry|
      signature_line = "static VALUE "

      arg_names = []
      map_entry.type_names.each do |t|
        resolved_gl_type = OpenGL::GL_TYPE_MAP[t]
        is_array = t.include?( "[" )
        is_ptr = t.end_with?( '*' )
        if !is_ptr && !is_array && resolved_gl_type == nil
          $stderr.puts "[ERROR] ruby-opengl generator script 'generate_command.rb' : Unknown type '#{t}' detected. Exiting..."
          exit
        end
        arg_names << ((is_ptr || is_array) ? 'void*' : resolved_gl_type)
      end


      # Signature
      signature_line += "rogl_#{api}(VALUE _obj_"
      # Arguments
      if arg_names.length > 0
        arg_names.each_with_index do |a, i|
          signature_line += ", VALUE _arg#{i+1}_"
        end
      end
      signature_line += ")"
      out.puts signature_line
      out.puts "{\n"
      # Begin implementation

      # Cast VALUE to C type
      if arg_names.length > 0
        arg_names.each_with_index do |a, i|
          arg_conv = get_value_to_ctype_converter(a)
          arg_cast = "(#{a})#{arg_conv}(_arg#{i+1}_)"
          out.puts "    #{a} #{map_entry.var_names[i]} = #{arg_cast};"
        end
        out.puts ""
      end

      # Function return value
      function_rettype = "#{map_entry.ret_name.end_with?( '*' ) ? 'void*' : OpenGL::GL_TYPE_MAP[map_entry.ret_name]}"
      function_retstr = ""
      if function_rettype == "void"
        function_retstr = ""
      else
        function_retstr = function_rettype + " retval = "
      end

      # Function call
      function_call_line = ""
      function_call_line += "    #{function_retstr}rogl_pfn_#{api}("
      if arg_names.length > 0
        arg_names.each_with_index do |a, i|
          function_call_line += "#{map_entry.var_names[i]}%s"%[(i < arg_names.length-1 ? ", " : "")]
        end
      end
      function_call_line += ");"
      out.puts function_call_line
      out.puts ""

      # Return value
      ret_conv = get_ctype_to_value_converter(function_rettype)
      ret_cast = "#{ret_conv}(retval)"
      out.puts "    return #{function_rettype == 'void' ? 'Qnil' : ret_cast};"

      # End implementation
      out.puts "}\n\n"

    end

    out.puts ""

    # Command/Enum initializer
    # Command
    out.puts "static void rogl_InitRubyCommand( VALUE* pmROGL )"
    out.puts "{"
    gl_std_cmd_map.each_pair do |api, map_entry|
      out.puts "    rb_define_method(*pmROGL, \"#{api}\", rogl_#{api}, #{map_entry.type_names.length});"
    end
    out.puts "}"
    out.puts ""

    # Enum
    out.puts "static void rogl_InitRubyEnum( VALUE* pmROGL )"
    out.puts "{"
    gl_std_enum_map.each do |enum|
      out.print "    rb_define_const(*pmROGL, \"#{enum[0]}\", UINT2NUM(#{enum[1]}));\n"
    end
    out.puts "}"
    out.puts ""

    out.puts "static void rogl_SetupFeature( int load_core )"
    out.puts "{"
    gl_std_cmd_map.each_pair do |api, map_entry|
      out.puts "    rogl_pfn_#{api} = rogl_GetProcAddress(\"#{api}\");"
    end
    out.puts "}"

  end

end

if $0 == __FILE__
  GLCodeGenerator.generate_command( $stdout )
end
