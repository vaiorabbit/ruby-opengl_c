<!-- -*- mode:markdown; coding:utf-8; -*- -->

# Ruby OpenGL Bindings (C Edition) #

Replaces pure-ruby OpenGL API calls in opengl-bindings ( https://github.com/vaiorabbit/ruby-opengl ) with native C function calls.

*   Created : 2015-10-11
*   Last modified : 2016-01-03

## Features ##

*   An extension library for MRI
	*   More faster and memory efficient
*   Provides same interface
	*   (In theory) You don't have to rewrite your code.


## Usage ##

1.  $ gem install opengl-bindings_c
2.  require 'opengl'
    *   opengl-bindings (v1.5.1 and later) tries to load opengl_c first.

## Notice ##

*   There's no need to use this gem if you don't suffer performance/memory matter.

*   glGetString and glGetStringi return String instance.
*   APIs listed below return Fiddle::Pointer instance.
    *   glMapBuffer
    *   glMapBufferRange
    *   glFenceSync
    *   glMapNamedBuffer
    *   glMapNamedBufferRange
    *   glCreateSyncFromCLeventARB
    *   glGetHandleARB
    *   glCreateShaderObjectARB
    *   glCreateProgramObjectARB
    *   glMapBufferARB
    *   glMapObjectBufferATI
    *   glMapNamedBufferEXT
    *   glMapNamedBufferRangeEXT
    *   glImportSyncEXT
    *   glMapTexture2DINTEL


## License ##

The zlib/libpng License ( http://opensource.org/licenses/Zlib ).

    Copyright (c) 2013-2015 vaiorabbit <http://twitter.com/vaiorabbit>

    This software is provided 'as-is', without any express or implied
    warranty. In no event will the authors be held liable for any damages
    arising from the use of this software.

    Permission is granted to anyone to use this software for any purpose,
    including commercial applications, and to alter it and redistribute it
    freely, subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
       claim that you wrote the original software. If you use this software in a
       product, an acknowledgment in the product documentation would be
       appreciated but is not required.

    2. Altered source versions must be plainly marked as such, and must not be
       misrepresented as being the original software.

    3. This notice may not be removed or altered from any source distribution.
