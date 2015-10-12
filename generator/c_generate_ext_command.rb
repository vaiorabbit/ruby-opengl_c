require_relative 'c_generate_common'

module GLExtCodeGenerator

  def self.generate_command( out )

    doc = REXML::Document.new(open("./gl.xml"))

    gl_ext_name_to_commands_map = build_name_to_commands_map(doc)
    gl_ext_name_to_enums_map = build_name_to_enums_map(doc)

    # Output
    out.puts <<-PROLOGUE
/* opengl-bindings
 * * http://rubygems.org/gems/opengl-bindings_c
 * * http://github.com/vaiorabbit/ruby-opengl_c
 *
 * [NOTICE] This is an automatically generated file.
 */
PROLOGUE
    generate_entry_point(out, gl_ext_name_to_commands_map)
    generate_function_call(out, gl_ext_name_to_commands_map, gl_ext_name_to_enums_map)

  end

  def self.build_name_to_commands_map(doc)
    # Collect all command
    gl_all_cmd_map = {}
    REXML::XPath.each(doc,'registry/commands/command') do |cmd_tag|

      # For extension parsing, aliases should be collected.
      # ex.) glBlendFuncIndexedAMD (alias of glBlendFunci), etc.
      # alias_tag = cmd_tag.get_elements('alias')
      # next if alias_tag.length != 0 # skips glActiveTextureARB (alias of glActiveTexture), etc.

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

    # Extract extension command
    gl_ext_all_command_names = []
    gl_ext_shared_command_names = []
    gl_ext_name_to_commands_map = {}
    REXML::XPath.each(doc, 'registry/extensions/extension') do |extension_tag|
      if extension_tag.attribute('supported').value.split('|').include?( 'gl' ) # ignoring "gles1", "glcore", etc.

        # Extension name (GL_NV_fence, etc.)
        ext_name =  extension_tag.attribute('name').value

        # Extension commands (glGenFencesNV, etc.)
        ext_command_map = {}
        REXML::XPath.each(extension_tag, 'require/command') do |tag|
          command_name = tag.attribute('name').value
          if gl_ext_all_command_names.include? command_name
            gl_ext_shared_command_names << command_name
          else
            ext_command_map[command_name] = gl_all_cmd_map[command_name]
            gl_ext_all_command_names << command_name
          end
        end

        # Create mapping table ("GL_NV_fence" => {"glGenFencesNV" => ...}, etc.)
        gl_ext_name_to_commands_map[ext_name] = ext_command_map
      end
    end

    # Remove reused tokens (e.g. OpenGL 4.3 reuses ARB_compute_shader (glDispatchCompute, etc.).)
    gl_ext_name_to_commands_map.each_pair do |ext_name, ext_commands|
      next if ext_commands.length == 0
      reused_tokens = []
      ext_commands.each_pair do |api, map_entry|
        reused_tokens << api if gl_std_cmd_map.has_key? api
      end
      ext_commands.delete_if { |key, value| reused_tokens.include? key }
    end

    # Remove shared tokens (e.g. Tokens of ARB_vertex_program are shared GL_ARB_fragment_program.)
    gl_ext_name_to_commands_map.each_pair do |ext_name, ext_commands|
      next if ext_commands.length == 0
      shared_tokens = []
      ext_commands.each_pair do |api, map_entry|
        shared_tokens << api if gl_ext_shared_command_names.include? api
      end
      ext_commands.delete_if { |key, value| shared_tokens.include? key }
      gl_ext_shared_command_names.delete_if { |item| shared_tokens.include? item }
    end

    return gl_ext_name_to_commands_map

  end

  def self.build_name_to_enums_map(doc)
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

    # Extract extension enum
    gl_ext_all_enum_names = []
    gl_ext_shared_enum_names = []
    gl_ext_name_to_enums_map = {}
    REXML::XPath.each(doc, 'registry/extensions/extension') do |extension_tag|
      if extension_tag.attribute('supported').value.split('|').include?( 'gl' ) # ignoring "gles1", "glcore", etc.

        # Extension name (GL_NV_fence, etc.)
        ext_name =  extension_tag.attribute('name').value

        # Extension enums (GL_FENCE_STATUS_NV, etc.)
        ext_enum_map = {}
        REXML::XPath.each(extension_tag, 'require/enum') do |tag|
          enum_name = tag.attribute('name').value
          if gl_ext_all_enum_names.include? enum_name
            gl_ext_shared_enum_names << enum_name
          else
            ext_enum_map[enum_name] = gl_all_enum_map[enum_name]
            gl_ext_all_enum_names << enum_name
          end
        end

        # Create mapping table ("GL_NV_fence" => {"GL_FENCE_STATUS_NV" => 0x84F3}, etc.)
        gl_ext_name_to_enums_map[ext_name] = ext_enum_map

      end
    end

    # Remove reused tokens (e.g. OpenGL 4.3 reuses ARB_compute_shader (glDispatchCompute, etc.).)
    gl_ext_name_to_enums_map.each_pair do |ext_name, ext_enums|
      next if ext_enums.length == 0
      reused_tokens = []
      ext_enums.each do |enums|
        reused_tokens << enums[0] if gl_std_enum_map.has_key? enums[0]
      end
      ext_enums.delete_if { |item| reused_tokens.include? item }
    end

    # Remove shared tokens (e.g. Tokens of ARB_vertex_program are shared GL_ARB_fragment_program.)
    gl_ext_name_to_enums_map.each_pair do |ext_name, ext_enums|
      next if ext_enums.length == 0
      shared_tokens = []
      ext_enums.each do |enums|
        shared_tokens << enums[0] if gl_ext_shared_enum_names.include? enums[0]
      end
      ext_enums.delete_if { |item| shared_tokens.include? item }
      gl_ext_shared_enum_names.delete_if { |item| shared_tokens.include? item }
    end

    return gl_ext_name_to_enums_map

  end

  def self.generate_entry_point(out, gl_ext_name_to_commands_map)

    # Typedef
    gl_ext_name_to_commands_map.each_pair do |ext_name, ext_commands|
      next if ext_commands.length == 0
      ext_commands.each_pair do |api, map_entry|
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
    end

    out.puts ""

    # Entry points
    gl_ext_name_to_commands_map.each_pair do |ext_name, ext_commands|
      next if ext_commands.length == 0
      ext_commands.each_pair do |api, map_entry|
        out.puts "static ROGL_PFN#{api.upcase}PROC rogl_pfn_#{api} = NULL;"
      end
    end
  end


  def self.generate_function_call(out, gl_ext_name_to_commands_map, gl_ext_name_to_enums_map)

    out.puts ""

    # Function call
    gl_ext_name_to_commands_map.each_pair do |ext_name, ext_commands|
      next if ext_commands.length == 0
      ext_commands.each_pair do |api, map_entry|
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
    end

    out.puts ""

    # Command/Enum initializer
    # Command
    out.puts "static void rogl_InitRubyExtCommand( VALUE* pmROGL )"
    out.puts "{"
    gl_ext_name_to_commands_map.each_pair do |ext_name, ext_commands|
      next if ext_commands.length == 0
      ext_commands.each_pair do |api, map_entry|
        out.puts "    rb_define_method(*pmROGL, \"#{api}\", rogl_#{api}, #{map_entry.type_names.length});"
      end
    end
    out.puts "}"
    out.puts ""

    # Enum
    out.puts "static void rogl_InitRubyExtEnum( VALUE* pmROGL )"
    out.puts "{"
    gl_ext_name_to_enums_map.each_pair do |ext_name, ext_enums|
      next if ext_enums.length == 0
      ext_enums.each do |enums|
        out.print "    rb_define_const(*pmROGL, \"#{enums[0]}\", UINT2NUM(#{enums[1]}));\n"
      end
    end
    out.puts "}"
    out.puts ""

    out.puts "static void rogl_SetupExtFeature( int load_core )"
    out.puts "{"
    gl_ext_name_to_commands_map.each_pair do |ext_name, ext_commands|
      next if ext_commands.length == 0
      ext_commands.each_pair do |api, map_entry|
        out.puts "    rogl_pfn_#{api} = rogl_GetProcAddress(\"#{api}\");"
      end
    end
    out.puts "}"

  end

end

if $0 == __FILE__
  GLExtCodeGenerator.generate_ext_command( $stdout )
end
