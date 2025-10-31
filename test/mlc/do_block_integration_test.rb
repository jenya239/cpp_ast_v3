# frozen_string_literal: true

require_relative "../test_helper"

class DoBlockIntegrationTest < Minitest::Test
  def test_do_block_with_math_stdlib
    source = <<~AURORA
      import { sqrt_f } from "Math"

      fn distance() -> f32 = do
        let x = 3.0;
        let y = 4.0;
        sqrt_f(x * x + y * y)
      end
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "sqrt_f"
    assert_includes cpp, "3.0"
    assert_includes cpp, "4.0"
  end

  def test_do_block_with_io_stdlib
    source = <<~AURORA
      import { println } from "IO"

      fn greet(name: str) -> i32 = do
        println("Hello, " + name);
        0
      end
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "println"
    assert_includes cpp, "greet"
  end

  def test_nested_do_blocks_compile
    source = <<~AURORA
      fn compute() -> i32 = do
        let x = do
          let a = 10;
          a * 2
        end;
        let y = do
          20
        end;
        x + y
      end
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "compute"
    assert_includes cpp, "10"
    assert_includes cpp, "20"
  end

  def test_do_block_with_function_calls
    source = <<~AURORA
      import { println } from "IO"

      fn helper() -> i32 = 42

      fn main() -> i32 = do
        let result = helper();
        println("Result");
        result
      end
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "helper"
    assert_includes cpp, "println"
    assert_includes cpp, "main"
  end

  def test_do_block_complex_example
    source = <<~AURORA
      import { sqrt_f, pow_f } from "Math"

      fn calculate() -> f32 = do
        let a = 3.0;
        let b = 4.0;
        let a_sq = pow_f(a, 2.0);
        let b_sq = pow_f(b, 2.0);
        let result = sqrt_f(a_sq + b_sq);
        result
      end
    AURORA

    ast = MLC.parse(source)
    assert_equal 1, ast.imports.length
    assert_equal 1, ast.declarations.length

    func = ast.declarations.first
    # Now returns BlockExpr with statements and result_expr
    assert func.body.is_a?(MLC::AST::BlockExpr)
    # 5 statements (let a, let b, let a_sq, let b_sq, let result) + 1 result (result)
    assert_equal 5, func.body.statements.length
    assert func.body.result_expr.is_a?(MLC::AST::VarRef)

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "calculate"
    assert_includes cpp, "sqrt_f"
    assert_includes cpp, "pow_f"
  end
end
