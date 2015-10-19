require 'rexml/document'
require_relative 'c_aux_typemap'

GLCommandMapEntry = Struct.new( :api_name, :ret_name, :type_names, :var_names )

# type = :command | :enum, required/removed = version string
# ex.) glFogCoordf (Introduced at OpenGL 1.4, and removed from core profile at OpenGL 3.2)
# "glFogCoordf"=>
#  #<struct Struct::FeatureInfo
#   type=:command,
#   required="GL_VERSION_1_4",
#   removed="GL_VERSION_3_2">,
FeatureInfo = Struct.new("FeatureInfo", :type, :required, :required_number, :removed, :removed_number)

def get_value_to_ctype_converter(type)
  case type
  when "void"; ""
  when "void*"; "val2ptr"
  when "unsigned char"; "NUM2UINT"
  when "char"; "NUM2INT"
  when "unsigned short"; "NUM2UINT"
  when "short"; "NUM2INT"
  when "unsigned int"; "NUM2UINT"
  when "int"; "NUM2INT"
  when "unsigned long"; "NUM2ULONG"
  when "long"; "NUM2LONG"
  when "unsigned long long"; "NUM2ULL"
  when "long long"; "NUM2LL"
  when "float"; "NUM2DBL"
  when "double"; "NUM2DBL"
  when "ptrdiff_t"; "NUM2UINT"
  end
end

def get_ctype_to_value_converter(type)
  case type
  when "void"; ""
  when "void*"; "CPOINTER_AS_VALUE"
  when "unsigned char"; "UINT2NUM"
  when "char"; "INT2NUM"
  when "unsigned short"; "UINT2NUM"
  when "short"; "INT2NUM"
  when "unsigned int"; "UINT2NUM"
  when "int"; "INT2NUM"
  when "unsigned long"; "ULONG2NUM"
  when "long"; "LONG2NUM"
  when "unsigned long long"; "ULL2NUM"
  when "long long"; "LL2NUM"
  when "float"; "DBL2NUM"
  when "double"; "DBL2NUM"
  when "ptrdiff_t"; "UINT2NUM"
  end
end

module GLCodeGeneratorCommon

  HeaderCommentRuby = <<-HEADER
# opengl-bindings
# * http://rubygems.org/gems/opengl-bindings_c
# * http://github.com/vaiorabbit/ruby-opengl_c
#
# [NOTICE] This is an automatically generated file.
  HEADER

  HeaderCommentC = <<-HEADER
/* opengl-bindings
 * * http://rubygems.org/gems/opengl-bindings_c
 * * http://github.com/vaiorabbit/ruby-opengl_c
 *
 * [NOTICE] This is an automatically generated file.
 */
  HEADER

  # Build feature map (Unused currently)

  def self.build_feature_map(doc)
    features = Hash.new
    REXML::XPath.each(doc, 'registry/feature') do |feature_tag|
      if "gl" == feature_tag.attribute('api').value
        version_string = feature_tag.attribute('name').value
        version_number = feature_tag.attribute('number').value.to_f
        # Required command
        REXML::XPath.each(feature_tag, 'require/command') do |tag|
          name_string = tag.attribute('name').value
          unless features.has_key?(name_string)
            features[name_string] = FeatureInfo.new(:command, version_string, version_number, nil, 0.0)
          end
        end
        # Required enum
        REXML::XPath.each(feature_tag, 'require/enum') do |tag|
          name_string = tag.attribute('name').value
          unless features.has_key?(name_string)
            features[name_string] = FeatureInfo.new(:enum, version_string, version_number, nil, 0.0)
          end
        end
      end
    end

    # Collect removed feature
    REXML::XPath.each(doc, 'registry/feature') do |feature_tag|
      if "gl" == feature_tag.attribute('api').value
        version_string = feature_tag.attribute('name').value
        version_number = feature_tag.attribute('number').value.to_f
        # Removed command
        REXML::XPath.each(feature_tag, 'remove/command') do |tag|
          name_string = tag.attribute('name').value
          if features.has_key?(name_string)
            features[name_string].removed = version_string
            features[name_string].removed_number = version_number
          end
        end
        # Removed enum
        REXML::XPath.each(feature_tag, 'remove/enum') do |tag|
          name_string = tag.attribute('name').value
          if features.has_key?(name_string)
            features[name_string].removed = version_string
            features[name_string].removed_number = version_number
          end
        end
      end
    end

    return features
  end

  def self.collect_commands(doc, check_alias: true)
    # Collect all command
    gl_all_cmd_map = {}
    REXML::XPath.each(doc,'registry/commands/command') do |cmd_tag|
      # Check alias
      # For extension parsing, aliases should be collected.
      # ex.) glBlendFuncIndexedAMD (alias of glBlendFunci), etc.
      if check_alias
        alias_tag = cmd_tag.get_elements('alias')
        next if alias_tag.length != 0 # skips glActiveTextureARB (alias of glActiveTexture), etc.
      end

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

    return gl_all_cmd_map
  end

  def self.build_commands_map(doc, extract_api: "gl")
    # Collect all command
    gl_all_cmd_map = collect_commands(doc, check_alias: true)

    # Extract standard command
    gl_cmd_map = {}
    REXML::XPath.each(doc, 'registry/feature') do |feature_tag|
      if extract_api == feature_tag.attribute('api').value

        # OpenGL Standard enums
        REXML::XPath.each(feature_tag, 'require/command') do |tag|
          gl_cmd_map[tag.attribute('name').value] = gl_all_cmd_map[tag.attribute('name').value]
        end

      end
    end

    return gl_cmd_map
  end

  def self.build_ext_commands_map(doc, extract_api: "gl")
    # Collect all command
    gl_all_cmd_map = collect_commands(doc, check_alias: false)

    # Extract extension command
    gl_ext_name_to_commands_map = {}
    REXML::XPath.each(doc, 'registry/extensions/extension') do |extension_tag|
      if extension_tag.attribute('supported').value.split('|').include?( extract_api ) # ignoring "gles1", "glcore", etc.

        # Extension name (GL_NV_fence, etc.)
        ext_name =  extension_tag.attribute('name').value

        # Extension commands (glGenFencesNV, etc.)
        ext_command_map = {}
        REXML::XPath.each(extension_tag, 'require/command') do |tag|
          ext_command_map[tag.attribute('name').value] = gl_all_cmd_map[tag.attribute('name').value]
        end

        # Create mapping table ("GL_NV_fence" => {"glGenFencesNV" => ...}, etc.)
        gl_ext_name_to_commands_map[ext_name] = ext_command_map
      end
    end

    return gl_ext_name_to_commands_map
  end

  def self.build_enums_map(doc, extract_api: "gl")
    # Collect all enum
    gl_all_enum_map = {}
    REXML::XPath.each(doc, 'registry/enums/enum') do |enum_tag|
      # # check alias
      # alias_attr = enum_tag['alias']
      # next if alias_attr != nil

      gl_all_enum_map[enum_tag.attribute('name').value] = enum_tag.attribute('value').value
    end

    # Extract standard enum
    gl_enum_map = {}
    REXML::XPath.each(doc, 'registry/feature') do |feature_tag|
      if extract_api == feature_tag.attribute('api').value

        # OpenGL Standard enums
        REXML::XPath.each(feature_tag, 'require/enum') do |tag|
          gl_enum_map[tag.attribute('name').value] = gl_all_enum_map[tag.attribute('name').value]
        end

      end
    end

    return gl_enum_map

  end

end
