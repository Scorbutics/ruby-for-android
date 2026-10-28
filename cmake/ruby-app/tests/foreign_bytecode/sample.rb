# Edge cases of the bytecode format: every place where a 32-bit dump
# stores a machine word or a special constant.
out = []

# Fixnums around the 32-bit Fixnum range, bignums, negative values
out << [0, 1, -1, 2**29, -2**29, 2**30 - 1, -2**30, 2**30, -2**30 - 1, 2**31, 2**62 - 1]
out << [12345678901234567890, -98765432109876543210987654321, 2**64, -(2**100)]

# Special constants and floats (no flonum on 32-bit)
out << [nil, true, false, 0.0, -0.0, 1.5, 3.14159, -2.5e-300, 1e300, Float::INFINITY]

# Ranges (struct with long fields), including endless/beginless
out << [(1..10), (1...10), ('a'..'z'), (1..), (..5), (1.5..2.5), (2**40..2**41)]

# Complex and Rational literals
out << [3r, 1.5r, 2i, 3+4i, (1/3r)]

# Regexps, strings with encodings, symbols, frozen literals
out << [/ab+c/i, /\d{2,}/m, "utf8 é", "bin\xff".b, :sym, :"quoted sym", %i[a b c]]
out << "frozen literal".frozen?

# Hashes and arrays literals (duparray / duphash)
out << { a: 1, "b" => [2, 3], 4 => nil }
out << [[1, 2], [3, [4, 5]]]

# case with large integers, floats, strings (opt_case_dispatch CDHASH)
def classify(x)
  case x
  when 1 then :one
  when 2**40 then :big
  when -7 then :neg
  when 2.5 then :float
  when "str" then :string
  when :sym then :symbol
  when nil then :nil
  else :other
  end
end
out << [1, 2**40, -7, 2.5, "str", :sym, nil, 99].map { |x| classify(x) }

# Optional args (opt_table), keywords with defaults (param keyword struct)
def opts(a, b = 2, c = 3 * b, *rest, d:, e: 5, f: [e], **kw, &blk)
  [a, b, c, rest, d, e, f, kw, blk&.call]
end
out << opts(1, d: 4)
out << opts(1, 9, 8, 7, 6, d: 4, e: -1, z: 0) { :blk }

def kw_only(x: -1, y: 2**40, z: nil) = [x, y, z]
out << kw_only
out << kw_only(z: :given)

# Loops with backward jumps, while/until, break/next/redo, catch tables
i = 0
acc = []
while i < 5
  i += 1
  next if i == 2
  acc << i
end
until i == 0
  i -= 1
end
acc << i
out << acc
out << (1..20).each_slice(3).map(&:sum)

begin
  raise ArgumentError, "boom"
rescue ArgumentError => e
  out << e.message
ensure
  out << :ensured
end

r = [1, 2, 3].each_with_index.map do |v, idx|
  break :broken if v > 2
  v * idx
end
out << r

# Multiple assignment, splats, string interpolation, flip-flop
a, (b, c), *d = 1, [2, 3], 4, 5
out << [a, b, c, d]
out << "#{a} + #{b} = #{a + b}"
out << (1..10).select { |n| true if (n == 3)..(n == 5) }

# Blocks capturing outer variables, procs, lambdas, methods with blocks
counter = 0
inc = -> (n = 1) { counter += n }
3.times { inc.(2) }
out << counter
out << [1, 2, 3].inject { |s, x| s * x }

# Classes, modules, constants, class variables, instance variables, super
module Greeter
  GREETING = "hello"
  def greet = "#{GREETING} #{name}"
end
class Base
  @@count = 0
  attr_reader :name
  def initialize(name) = (@name = name; @@count += 1)
  def self.count = @@count
  def to_s = "Base(#{@name})"
end
class Child < Base
  include Greeter
  def to_s = "Child<#{super}>"
end
out << [Child.new("x").greet, Child.new("y").to_s, Base.count]

# Pattern matching (NoMatchingPatternError class index)
config = { name: "game", size: [640, 480] }
case config
in { name: String => nm, size: [w, h] } if w > h
  out << [nm, w, h]
end
begin
  case 5
  in String then nil
  end
rescue NoMatchingPatternError => e
  out << e.class
end

# defined?, global/special variables, backrefs
out << [defined?(foo), defined?(out), defined?(String), defined?(@iv)]
"abc123" =~ /(\d+)/
out << [$~[1], $1, $`]

# Encoding literal (T_DATA object)
out << [__ENCODING__, Encoding::UTF_8]

out
