# Foreign bytecode fixtures

`check_foreign_bytecode.cmake` loads these dumps of `sample.rb` with the built
Ruby (`load-foreign-bytecode.patch`, Ruby 3.0 and 3.2). `sample.rb` covers every
place where a dump depends on the dumping platform: Fixnum/Bignum boundaries,
special constants, floats, Range/Complex/Rational/Encoding objects, optional and
keyword parameters, backward jumps, catch tables, `case` dispatch hashes.

Each fixture is `sample-<platform>-<ruby version>.yarb`, the output of
`RubyVM::InstructionSequence.compile(src, "sample.rb", "sample.rb", 1).to_binary`
(`dump.rb` below). **Regenerate every fixture when `sample.rb` changes.**

| Fixture | Dumped by | Covers |
|---|---|---|
| `sample-i386-mingw32-3.0.1.yarb` | The Windows Ruby shipped with a Pokemon Studio release (`ruby.exe`, 3.0.1p64) under Wine | 32-bit words, Windows i386 `double` alignment (8), 3.0.0-3.0.2 iseq layout |
| `sample-i686-linux-3.0.7.yarb` | Ruby 3.0.7 built from source in `i386/debian:bookworm` (`linux32 ./configure --build=i686-pc-linux-gnu`, `make miniruby`) | 32-bit words, System V i386 `double` alignment (4), 3.0.3+ iseq layout |
| `sample-x86_64-linux-3.0.1.yarb` | Stock Ruby 3.0.1 `miniruby`, x86_64 Linux | 64-bit 3.0.0-3.0.2 iseq layout |
| `sample-arm64-darwin23-3.2.11.yarb` | Stock Ruby 3.2.11 `miniruby`, x86_64 Linux, with `RUBY_PLATFORM` set to `arm64-darwin23` in its `config.h` | macOS platform name (64-bit macOS and Linux dumps share their layout) |

```ruby
# dump.rb: ruby dump.rb sample.rb <out.yarb>
src = File.read(ARGV[0])
iseq = RubyVM::InstructionSequence.compile(src, "sample.rb", "sample.rb", 1)
File.binwrite(ARGV[1], iseq.to_binary)
```

Beyond these fixtures, the patch was checked against real game code: the 1636
PSDK scripts compiled by the Windows Ruby 3.0.1 and by Ruby 3.0.7 i686 disassemble
exactly like their x86_64 compiles, and a stock Studio Windows release (Game.yarb
and the 1772 scripts of Data/Scripts.dat) loads entirely.
