#ifndef RUBY_THREAD_EVENT_HOOKS_H                    /*-*-C++-*-vi:se ft=cpp:*/
#define RUBY_THREAD_EVENT_HOOKS_H 1
/**
 * @file
 * @brief  Internal thread events, backported from Ruby 3.2 (same API, same
 *         firing points): a hook runs when a thread starts, waits for the
 *         GVL, acquires it, releases it, and terminates. Native extensions
 *         with thread-bound state need them (LiteRGSS3's raylib backend
 *         hands its one GL context to the thread holding the GVL).
 *
 * Added by ruby-for-android (cmake/ruby-app/sources/ruby/3.0), included by
 * ruby/thread.h like 3.2 declares them there; the implementation is
 * thread_event_hooks.c, its firing points are in thread_pthread.c
 * (patches/ruby/3.0/internal-thread-event-hooks.patch).
 */
#include "ruby/ruby.h"                 /* rb_event_flag_t */
#include "ruby/internal/dllexport.h"
#include "ruby/internal/stdbool.h"

RBIMPL_SYMBOL_EXPORT_BEGIN()

#define RUBY_INTERNAL_THREAD_EVENT_STARTED    1 << 0 /** thread started */
#define RUBY_INTERNAL_THREAD_EVENT_READY      1 << 1 /** acquiring GVL */
#define RUBY_INTERNAL_THREAD_EVENT_RESUMED    1 << 2 /** acquired GVL */
#define RUBY_INTERNAL_THREAD_EVENT_SUSPENDED  1 << 3 /** released GVL */
#define RUBY_INTERNAL_THREAD_EVENT_EXITED     1 << 4 /** thread terminated */
#define RUBY_INTERNAL_THREAD_EVENT_MASK       0xff /** All Thread events */

typedef void rb_internal_thread_event_data_t; // for future extension.

typedef void (*rb_internal_thread_event_callback)(rb_event_flag_t event,
              const rb_internal_thread_event_data_t *event_data,
              void *user_data);
typedef struct rb_internal_thread_event_hook rb_internal_thread_event_hook_t;

/**
 * Registers a thread event hook function.
 *
 * @param[in]  func    A callback.
 * @param[in]  events  A set of events that `func` should run.
 * @param[in]  data    Passed as-is to `func`.
 * @return     An opaque pointer to the hook, to unregister it later.
 * @note       This functionality is a noop on Windows.
 * @warning    This function MUST not be called from a thread event callback.
 */
rb_internal_thread_event_hook_t *rb_internal_thread_add_event_hook(
        rb_internal_thread_event_callback func, rb_event_flag_t events,
        void *data);

/**
 * Unregister the passed hook.
 *
 * @param[in]  hook.  The hook to unregister.
 * @return     Wether the hook was found and unregistered.
 * @note       This functionality is a noop on Windows.
 * @warning    This function MUST not be called from a thread event callback.
 */
bool rb_internal_thread_remove_event_hook(
        rb_internal_thread_event_hook_t * hook);

RBIMPL_SYMBOL_EXPORT_END()

#endif /* RUBY_THREAD_EVENT_HOOKS_H */
