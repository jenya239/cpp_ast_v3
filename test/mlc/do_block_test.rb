# frozen_string_literal: true

require_relative "../test_helper"

class DoBlockTest < Minitest::Test
  def test_simple_do_block
    source = <<~AURORA
      fn test() -> i32 = do
        42
      end
    AURORA

    ast = MLC.parse(source)
    assert_equal 1, ast.declarations.length
    func = ast.declarations.first
    # Now returns BlockExpr instead of DoExpr
    assert func.body.is_a?(MLC::AST::BlockExpr)
    # BlockExpr has no statements, just result_expr
    assert_equal 0, func.body.statements.length
    assert func.body.result_expr.is_a?(MLC::AST::IntLit)
  end

  def test_do_block_multiple_expressions
    source = <<~AURORA
      fn test() -> i32 = do
        let x = 10;
        let y = 20;
        x + y
      end
    AURORA

    ast = MLC.parse(source)
    func = ast.declarations.first
    # Now returns BlockExpr
    assert func.body.is_a?(MLC::AST::BlockExpr)
    # 2 statements (let x, let y), 1 result (x + y)
    assert_equal 2, func.body.statements.length
    assert func.body.result_expr.is_a?(MLC::AST::BinaryOp)
  end

  def test_do_block_with_function_calls
    source = <<~AURORA
      fn greet() -> i32 = do
        println("Hello")
        println("World")
        0
      end
    AURORA

    ast = MLC.parse(source)
    func = ast.declarations.first
    # Now returns BlockExpr
    assert func.body.is_a?(MLC::AST::BlockExpr)
    # 2 statements (println calls), 1 result (0)
    assert_equal 2, func.body.statements.length
    assert func.body.result_expr.is_a?(MLC::AST::IntLit)
  end

  def test_do_block_compiles
    source = <<~AURORA
      fn compute() -> i32 = do
        let x = 10
        let y = 20
        x + y
      end
    AURORA

    cpp = MLC.to_cpp(source)
    assert_includes cpp, "compute"
    assert cpp.include?("10") || cpp.include?("20")
  end

  def test_nested_do_blocks
    source = <<~AURORA
      fn test() -> i32 = do
        let x = do
          10
        end
        x + 5
      end
    AURORA

    ast = MLC.parse(source)
    func = ast.declarations.first
    # Now returns BlockExpr
    assert func.body.is_a?(MLC::AST::BlockExpr)
    # Nested do-block also becomes BlockExpr
    assert func.body.statements.first.is_a?(MLC::AST::VariableDecl)
    assert func.body.statements.first.value.is_a?(MLC::AST::BlockExpr)
  end
end
