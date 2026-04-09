/*
 * link_test.c - Minimal program that references Ruby C API symbols.
 * Compiling and linking this against libruby-static.a (and its dependencies)
 * verifies that no symbols are missing from the cross-compiled libraries.
 */
#include "ruby.h"

int main(int argc, char **argv) {
    ruby_sysinit(&argc, &argv);
    ruby_init();
    ruby_init_loadpath();
    rb_eval_string("nil");
    return ruby_cleanup(0);
}
