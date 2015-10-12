#include <stddef.h>
#include <ruby.h>
#include "rogl_proc_address.h"

#if SIZEOF_VOIDP == SIZEOF_LONG_LONG
#define CPOINTER_AS_VALUE(ptr) (ULL2NUM((unsigned long long)(ptr)))
#define VALUE_AS_CPOINTER(obj) ((void*)(NUM2ULL(obj)))
#else
#define CPOINTER_AS_VALUE(ptr) (ULONG2NUM((unsigned long)(ptr)))
#define VALUE_AS_CPOINTER(obj) ((void*)(NUM2ULONG(obj)))
#endif

static void* val2ptr(VALUE obj)
{
    /* Ref.:
       Ruby Strings vs. C strings
         http://stackoverflow.com/questions/7050800/ruby-c-extensions-api-questions
     */
    if (NIL_P(obj))
    {
        return NULL;
    }
    else if (RB_TYPE_P(obj, T_STRING))
    {
        return RSTRING_PTR(obj);
    }
    else
    {
        return VALUE_AS_CPOINTER(obj);
    }
}

#include "rogl_commands.c.inc"
#include "rogl_ext_commands.c.inc"

static VALUE rogl_method_InitSystem( VALUE self, VALUE lib )
{
    int retval = rogl_InitProcAddressSystem(NIL_P(lib) ? NULL : RSTRING_PTR(lib));
    return retval == 1 ? Qtrue : Qfalse;
}

static VALUE rogl_method_TermSystem( VALUE self )
{
    rogl_TermProcAddressSystem();
    return Qnil;
}

static VALUE rogl_method_LoadLib(int argc, VALUE argv[], VALUE self)
{
    VALUE retval = Qnil;
    VALUE lib_name, lib_path;
    int n = rb_scan_args(argc, argv, "02", &lib_name, &lib_path);

    switch (n)
    {
    case 0:
    {
        retval = rogl_method_InitSystem(self, Qnil);
        break;
    }
    case 1:
    {
        retval = rogl_method_InitSystem(self, NIL_P(lib_name) ? lib_path : lib_name);
    }
    break;

    case 2:
    {
        VALUE lib_path_sl = rb_str_append(lib_path, rb_str_new2("/"));
        retval = rogl_method_InitSystem(self, rb_str_append(lib_path_sl, lib_name));
    }
    break;
    }

    if (retval == Qfalse)
    {
        return Qfalse;
    }

    /* TODO handle core/compatible */
    rogl_SetupFeature(0);
    rogl_SetupExtFeature(0);

    /* TODO call rogl_TermProcAddressSystem at exit? */

    return Qtrue;
}

void Init_opengl_c()
{
    VALUE mROGL = rb_define_module("OpenGL");

    rb_define_singleton_method( mROGL, "load_lib", rogl_method_LoadLib, -1 );

    rb_define_singleton_method( mROGL, "init_system", rogl_method_InitSystem, 1 );
    rb_define_singleton_method( mROGL, "term_system", rogl_method_TermSystem, 0 );

    rogl_InitRubyCommand( &mROGL );
    rogl_InitRubyExtCommand( &mROGL );
    rogl_InitRubyEnum( &mROGL );
    rogl_InitRubyExtEnum( &mROGL );
}

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
