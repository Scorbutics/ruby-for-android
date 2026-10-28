# miniruby check.rb <sample.rb> <fixture.yarb>...
#
# Loads bytecode of sample.rb dumped by other Rubies (fixture names:
# sample-<platform>-<ruby version>.yarb) with the running Ruby:
# - a fixture of the running Ruby minor must load, disassemble exactly like a
#   native compile of sample.rb, and evaluate to the same result;
# - a fixture of another minor must be refused (unmatched version);
# - on Ruby 3.0, a 32-bit fixture renamed to x64-mingw32 must be refused
#   (its long is 32-bit while its VALUE is 64-bit).
src = File.read(ARGV.shift)
native = RubyVM::InstructionSequence.compile(src, "sample.rb", "sample.rb", 1)
# Disassemble before running: the first zsuper call stores its method id in its call info.
expected_disasm = native.disasm
expected_result = native.eval.inspect
minor = RUBY_VERSION[/\A\d+\.\d+/]
failures = 0

def refused?(bin, message)
  RubyVM::InstructionSequence.load_from_binary(bin)
  false
rescue RuntimeError => e
  e.message.include?(message)
end

ARGV.each do |path|
  name = File.basename(path, ".yarb")
  platform, version = name.delete_prefix("sample-").split(/-(?=\d+\.\d+\.\d+\z)/)
  bin = File.binread(path)

  unless version.start_with?("#{minor}.")
    ok = refused?(bin, "unmatched version")
    puts "#{ok ? 'ok  ' : 'FAIL'} #{name}: refused by Ruby #{RUBY_VERSION}"
    failures += 1 unless ok
    next
  end

  begin
    loaded = RubyVM::InstructionSequence.load_from_binary(bin)
    if loaded.disasm != expected_disasm
      File.write("#{name}.native.txt", expected_disasm)
      File.write("#{name}.loaded.txt", loaded.disasm)
      puts "FAIL #{name}: disasm differs (see #{name}.{native,loaded}.txt)"
      failures += 1
    elsif (result = loaded.eval.inspect) != expected_result
      puts "FAIL #{name}: result differs\n  native: #{expected_result}\n  loaded: #{result}"
      failures += 1
    else
      puts "ok   #{name}: same disasm and result"
    end
  rescue => e
    puts "FAIL #{name}: #{e.class}: #{e.message}"
    failures += 1
  end

  # The platform name follows the 36-byte header; rename in place (NUL padded).
  if minor == "3.0" && platform.start_with?("i386-", "i686-") && platform.size >= "x64-mingw32".size
    renamed = bin.dup
    renamed[36, platform.size] = "x64-mingw32".ljust(platform.size, "\0")
    ok = refused?(renamed, "unmatched platform")
    puts "#{ok ? 'ok  ' : 'FAIL'} #{name}: refused as x64-mingw32"
    failures += 1 unless ok
  end
end

exit(failures.zero?)
