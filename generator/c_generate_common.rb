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

# Build feature map (Unused currently)
def build_feature_map(doc)
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
