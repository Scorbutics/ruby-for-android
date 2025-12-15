
export GEM_PATH="$ROOT/usr/local/lib/ruby/gems/$RUBY_VERSION/"
export GEM_HOME="$GEM_PATH"
export GEM_SPEC_CACHE="$ROOT/usr/local/lib/ruby/gems/$RUBY_VERSION/specifications/"
RUBY_ARCH_LIB_DIR="$(ls -d $ROOT/usr/local/lib/ruby/$RUBY_VERSION/$ARCH*)"
export RUBYLIB="$ROOT/usr/local/lib/:$ROOT/usr/local/lib/ruby/$RUBY_VERSION/:$RUBY_ARCH_LIB_DIR"

export PATH="$ROOT/usr/local/bin:${PATH}"
export LD_LIBRARY_PATH="$RUBYLIB:${LD_LIBRARY_PATH}"