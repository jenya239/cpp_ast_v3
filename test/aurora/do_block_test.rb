# frozen_string_literal: true

require_relative "../test_helper"

class DoBlockTest < Minitest::Test
  def test_simple_do_block
    source = <<~AURORA
      fn test() -> i32 = do
        42
      end
    AURORA

    ast = Aurora.parse(source)
    assert_equal 1, ast.declarations.length
    func = ast.declarations.first
    assert func.body.is_a?(Aurora::AST::DoExpr)
    assert_equal 1, func.body.body.length
  end

  def test_do_block_multiple_expressions
    source = <<~AURORA
      fn test() -> i32 = do
        let x = 10;
        let y = 20;
        x + y
      end
    AURORA

    ast = Aurora.parse(source)
    func = ast.declarations.first
    assert func.body.is_a?(Aurora::AST::DoExpr)
    assert_equal 3, func.body.body.length
  end

  def test_do_block_with_function_calls
    source = <<~AURORA
      fn greet() -> i32 = do
        println("Hello")
        println("World")
        0
      end
    AURORA

    ast = Aurora.parse(source)
    func = ast.declarations.first
    assert func.body.is_a?(Aurora::AST::DoExpr)
    assert_equal 3, func.body.body.length
  end

  def test_do_block_compiles
    source = <<~AURORA
      fn compute() -> i32 = do
        let x = 10
        let y = 20
        x + y
      end
    AURORA

    cpp = Aurora.to_cpp(source)
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

    ast = Aurora.parse(source)
    func = ast.declarations.first
    assert func.body.is_a?(Aurora::AST::DoExpr)
  end
end
