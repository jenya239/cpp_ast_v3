# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require_relative "../lib/cpp_ast"

module TestHelpers
  # Helper method to test roundtrip accuracy
  # Usage: assert_roundtrip "x = 42;\n"
  def assert_roundtrip(source)
    program = CppAst.parse(source)
    result = program.to_source
    
    assert_equal source, result,
      "Roundtrip failed:\nExpected: #{source.inspect}\nGot:      #{result.inspect}"
  end
end

class Minitest::Test
  include TestHelpers
end

