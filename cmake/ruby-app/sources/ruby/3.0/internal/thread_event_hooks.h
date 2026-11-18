#ifndef INTERNAL_THREAD_EVENT_HOOKS_H                /*-*-C-*-vi:se ft=c:*/
#define INTERNAL_THREAD_EVENT_HOOKS_H
/**
 * @file
 * @brief  Firing internal thread events (ruby/thread_event_hooks.h) from the
 *         thread implementation (thread_pthread.c), as Ruby 3.2 does.
 *         Added by ruby-for-android (cmake/ruby-app/sources/ruby/3.0).
 */
#include "ruby/thread_event_hooks.h"

/* The registered hooks (thread_event_hooks.c): NULL when there is none, so
   firing an event costs one load. */
extern rb_internal_thread_event_hook_t *rb_internal_thread_event_hooks;

/* Runs the hooks registered for event. */
void rb_thread_execute_hooks(rb_event_flag_t event);

#define RB_INTERNAL_THREAD_HOOK(event) if (rb_internal_thread_event_hooks) { rb_thread_execute_hooks(event); }

#endif /* INTERNAL_THREAD_EVENT_HOOKS_H */
