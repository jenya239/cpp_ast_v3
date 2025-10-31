# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc"

class AuroraPipeOperatorTest < Minitest::Test
  def test_parse_simple_pipe
    aurora_source = <<~AURORA
      fn double(x: i32) -> i32 = x + x

      fn test(x: i32) -> i32 =
        x |> double
    AURORA

    ast = MLC.parse(aurora_source)
    test_func = ast.declarations[1]

    # Body should be a pipe expression
    assert_instance_of MLC::AST::BinaryOp, test_func.body
    assert_equal "|>", test_func.body.op
  end

  def test_parse_chained_pipes
    aurora_source = <<~AURORA
      fn test(x: i32) -> i32 =
        x |> double |> triple |> square
    AURORA

    ast = MLC.parse(aurora_source)
    func = ast.declarations.first

    # Should be left-associative: ((x |> double) |> triple) |> square
    assert_instance_of MLC::AST::BinaryOp, func.body
    assert_equal "|>", func.body.op
  end

  def test_pipe_with_function_call
    aurora_source = <<~AURORA
      fn test(x: i32) -> i32 =
        x |> add(5) |> multiply(2)
    AURORA

    ast = MLC.parse(aurora_source)
    refute_nil ast
  end

  def test_pipe_lowering
    aurora_source = <<~AURORA
      fn double(x: i32) -> i32 = x + x

      fn test(x: i32) -> i32 =
        x |> double
    AURORA

    cpp_code = MLC.to_cpp(aurora_source)

    # Pipe should desugar to function call (with sanitized identifier)
    assert_includes cpp_code, "double_(x)"
  end
end
