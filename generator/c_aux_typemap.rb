module OpenGL
  GL_TYPE_MAP = {
    'GLenum' => 'unsigned int',
    'GLboolean' => 'unsigned char',
    'GLbitfield' => 'unsigned int',
    'GLvoid' => 'void',
    'GLbyte' => 'char',
    'GLshort' => 'short',
    'GLint' => 'int',
    'GLclampx' => 'int',
    'GLubyte' => 'unsigned char',
    'GLushort' => 'unsigned short',
    'GLuint' => 'unsigned int',
    'GLsizei' => 'int',
    'GLfloat' => 'float',
    'GLclampf' => 'float',
    'GLdouble' => 'double',
    'GLclampd' => 'double',
    'GLeglImageOES' => 'void*',
    'GLchar' => 'char',
    'GLcharARB' => 'char',
    'GLhandleARB' => 'void*', # <- *** [CHECK] should be 'void*' for __APPLE__ / 'unsigned int' otherwise.
    'GLhalfARB' => 'unsigned short',
    'GLhalf' => 'unsigned short',
    'GLfixed' => 'int',
    'GLintptr' => 'ptrdiff_t',
    'GLsizeiptr' => 'ptrdiff_t',
    'GLint64' => 'long long',
    'GLuint64' => 'unsigned long long',
    'GLintptrARB' => 'ptrdiff_t',
    'GLsizeiptrARB' => 'ptrdiff_t',
    'GLint64EXT' => 'long long',
    'GLuint64EXT' => 'unsigned long long',
    'GLsync' => 'void*',
    'struct _cl_context' => 'void*',
    'struct _cl_event' => 'void*',
    'GLDEBUGPROC' => 'void*',
    'GLDEBUGPROCARB' => 'void*',
    'GLDEBUGPROCKHR' => 'void*',
    'GLDEBUGPROCAMD' => 'void*',
    'GLhalfNV' => 'unsigned short',
    'GLvdpauSurfaceNV' => 'ptrdiff_t',

    'char' => 'char',
    'signed char' => 'char',
    'unsigned char' => 'unsigned char',
    'short' => 'short',
    'signed short' => 'short',
    'unsigned short' => 'unsigned short',
    'int' => 'int',
    'signed int' => 'int',
    'unsigned int' => 'unsigned int',
    'int64_t' => 'long long',
    'uint64_t' => 'unsigned long long',
    'float' => 'float',
    'double' => 'double',
    'ptrdiff_t' => 'ptrdiff_t',
    'void' => 'void',
    'void *' => 'void*',
  }
end
