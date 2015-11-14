#include "rogl_pointer.h"

VALUE g_mFiddlePointer;

void* val2ptr(VALUE obj)
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

static VALUE rogl_method_SetFiddlePointerModule( VALUE self, VALUE mFiddlePointer )
{
    g_mFiddlePointer = mFiddlePointer;

    return Qnil;
}

void rogl_InitPointerCommand( VALUE* pmROGL )
{
    rb_define_singleton_method( *pmROGL, "set_fiddle_pointer_module", rogl_method_SetFiddlePointerModule, 1 );
}
