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
  end
end

