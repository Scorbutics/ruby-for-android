# TODO: compute those variables from current execution setup

export ROOT="$(pwd)"
export RUBY_VERSION="3.1.0"
export ARCH="x86"

. constants.sh

ruby $@
