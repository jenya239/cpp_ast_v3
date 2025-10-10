# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require_relative "../lib/cpp_ast"

module TestHelpers
  def assert_roundtrip(source)
    program = CppAst.parse(source)
    
    assert_equal source, program.to_source, 
      "Roundtrip failed: source != AST.to_source"
  end
end

class Minitest::Test
  include TestHelpers
end

