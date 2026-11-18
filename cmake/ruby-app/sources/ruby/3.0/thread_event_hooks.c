/**********************************************************************

  thread_event_hooks.c -

  Internal thread events (rb_internal_thread_add_event_hook), backported
  from Ruby 3.2's thread_pthread.c / thread_win32.c: the same hook list,
  the same functions. Added by ruby-for-android
  (cmake/ruby-app/sources/ruby/3.0), compiled as its own object
  (COMMONOBJS in common.mk); thread_pthread.c fires the events through
  RB_INTERNAL_THREAD_HOOK (patches/ruby/3.0/internal-thread-event-hooks.patch).

**********************************************************************/

#include "ruby/internal/config.h"
#include "internal/thread_event_hooks.h"
#include "ruby/ruby.h"

#ifdef _WIN32

/* A noop on Windows, as in Ruby 3.2. */
rb_internal_thread_event_hook_t *rb_internal_thread_event_hooks = NULL;

rb_internal_thread_event_hook_t *
rb_internal_thread_add_event_hook(rb_internal_thread_event_callback callback, rb_event_flag_t internal_event, void *user_data)
{
    // not implemented
    return NULL;
}

bool
rb_internal_thread_remove_event_hook(rb_internal_thread_event_hook_t * hook)
{
    // not implemented
    return false;
}

void
rb_thread_execute_hooks(rb_event_flag_t event)
{
}

#else /* pthread */

#include <pthread.h>
#include "ruby_atomic.h"

struct rb_internal_thread_event_hook {
    rb_internal_thread_event_callback callback;
    rb_event_flag_t event;
    void *user_data;

    struct rb_internal_thread_event_hook *next;
};

rb_internal_thread_event_hook_t *rb_internal_thread_event_hooks = NULL;
static pthread_rwlock_t rb_internal_thread_event_hooks_rw_lock = PTHREAD_RWLOCK_INITIALIZER;

rb_internal_thread_event_hook_t *
rb_internal_thread_add_event_hook(rb_internal_thread_event_callback callback, rb_event_flag_t internal_event, void *user_data)
{
    rb_internal_thread_event_hook_t *hook = ALLOC_N(rb_internal_thread_event_hook_t, 1);
    hook->callback = callback;
    hook->user_data = user_data;
    hook->event = internal_event;

    int r;
    if ((r = pthread_rwlock_wrlock(&rb_internal_thread_event_hooks_rw_lock))) {
        rb_bug_errno("pthread_rwlock_wrlock", r);
    }

    hook->next = rb_internal_thread_event_hooks;
    ATOMIC_PTR_EXCHANGE(rb_internal_thread_event_hooks, hook);

    if ((r = pthread_rwlock_unlock(&rb_internal_thread_event_hooks_rw_lock))) {
        rb_bug_errno("pthread_rwlock_unlock", r);
    }
    return hook;
}

bool
rb_internal_thread_remove_event_hook(rb_internal_thread_event_hook_t * hook)
{
    int r;
    if ((r = pthread_rwlock_wrlock(&rb_internal_thread_event_hooks_rw_lock))) {
        rb_bug_errno("pthread_rwlock_wrlock", r);
    }

    bool success = FALSE;

    if (rb_internal_thread_event_hooks == hook) {
        ATOMIC_PTR_EXCHANGE(rb_internal_thread_event_hooks, hook->next);
        success = TRUE;
    }
    else {
        rb_internal_thread_event_hook_t *h = rb_internal_thread_event_hooks;

        do {
            if (h->next == hook) {
                h->next = hook->next;
                success = TRUE;
                break;
            }
        } while ((h = h->next));
    }

    if ((r = pthread_rwlock_unlock(&rb_internal_thread_event_hooks_rw_lock))) {
        rb_bug_errno("pthread_rwlock_unlock", r);
    }

    if (success) {
        ruby_xfree(hook);
    }
    return success;
}

void
rb_thread_execute_hooks(rb_event_flag_t event)
{
    int r;
    if ((r = pthread_rwlock_rdlock(&rb_internal_thread_event_hooks_rw_lock))) {
        rb_bug_errno("pthread_rwlock_rdlock", r);
    }

    if (rb_internal_thread_event_hooks) {
        rb_internal_thread_event_hook_t *h = rb_internal_thread_event_hooks;
        do {
            if (h->event & event) {
                (*h->callback)(event, NULL, h->user_data);
            }
        } while((h = h->next));
    }
    if ((r = pthread_rwlock_unlock(&rb_internal_thread_event_hooks_rw_lock))) {
        rb_bug_errno("pthread_rwlock_unlock", r);
    }
}

#endif /* _WIN32 */
