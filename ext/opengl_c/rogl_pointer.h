#ifndef ROGL_POINTER_H
#define ROGL_POINTER_H

#include <stddef.h>
#include <ruby.h>

extern VALUE g_mFiddlePointer;

#if SIZEOF_VOIDP == SIZEOF_LONG_LONG
#define VALUE_AS_CPOINTER(obj) ((void*)(NUM2ULL(obj)))
#define CPOINTER_AS_VALUE(ptr) rb_funcall(g_mFiddlePointer, rb_intern("new"), 1, (ULL2NUM((unsigned long long)(ptr))))
#else
#define VALUE_AS_CPOINTER(obj) ((void*)(NUM2ULONG(obj)))
#define CPOINTER_AS_VALUE(ptr) rb_funcall(g_mFiddlePointer, rb_intern("new"), 1, (ULONG2NUM((unsigned long)(ptr))))
#endif

void* val2ptr(VALUE obj);

void rogl_InitPointerCommand( VALUE* pmROGL );

#endif
