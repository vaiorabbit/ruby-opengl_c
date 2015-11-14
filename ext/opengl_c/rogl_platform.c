#include "rogl_platform.h"
#include "rogl_pointer.h"

#if defined(__APPLE__)

#include <OpenGL/OpenGL.h>

static VALUE rogl_method_CGLGetCurrentContext( VALUE self )
{
    CGLContextObj ctxobj = CGLGetCurrentContext();

    return CPOINTER_AS_VALUE(ctxobj);
}

static VALUE rogl_method_CGLGetShareGroup( VALUE self, VALUE ctxval )
{
    CGLContextObj ctxobj = (CGLContextObj)VALUE_AS_CPOINTER(ctxval);
    CGLShareGroupObj sgobj = CGLGetShareGroup(ctxobj);

    return CPOINTER_AS_VALUE(sgobj);
}

void rogl_InitPlatformCommand( VALUE* pmROGL )
{
    rb_define_method(*pmROGL, "CGLGetCurrentContext", rogl_method_CGLGetCurrentContext, 0);
    rb_define_method(*pmROGL, "CGLGetShareGroup", rogl_method_CGLGetShareGroup, 1);
}

#elif defined(_WIN32)

void rogl_InitPlatformCommand( VALUE* pmROGL )
{
}

#elif defined(__linux__)

void rogl_InitPlatformCommand( VALUE* pmROGL )
{
}

#else
#  error "Unknown Platform"
#endif

/*
Ruby-OpenGL : Yet another OpenGL wrapper for Ruby (and wrapper code generator)
Copyright (c) 2013-2015 vaiorabbit <http://twitter.com/vaiorabbit>

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

    1. The origin of this software must not be misrepresented; you must not
    claim that you wrote the original software. If you use this software
    in a product, an acknowledgment in the product documentation would be
    appreciated but is not required.

    2. Altered source versions must be plainly marked as such, and must not be
    misrepresented as being the original software.

    3. This notice may not be removed or altered from any source
    distribution.
 */
