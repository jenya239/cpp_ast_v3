# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraBlockTest < Minitest::Test
  def test_for_loop_block_ast
    source = <<~AUR
      fn pick(xs: i32[]) -> i32 =
        for x in xs do
          x
        end
    AUR

    ast = Aurora.parse(source)
    func = ast.declarations.first

    assert_instance_of Aurora::AST::ForLoop, func.body
    # Now uses BlockExpr instead of Block
    assert_instance_of Aurora::AST::BlockExpr, func.body.body
    assert_equal 0, func.body.body.statements.size
    assert_instance_of Aurora::AST::VarRef, func.body.body.result_expr
  end

  def test_block_with_variable_and_assignment
    source = <<~AUR
      fn sum(xs: i32[]) -> i32 =
        for x in xs do
          let mut total = 0;
          total = total + x;
          total
        end
    AUR

    ast = Aurora.parse(source)
    block = ast.declarations.first.body.body

    # BlockExpr: 2 statements (let, assignment) + 1 result (total)
    assert_equal 2, block.statements.size
    assert_instance_of Aurora::AST::VariableDecl, block.statements[0]
    assert block.statements[0].mutable
    assert_instance_of Aurora::AST::Assignment, block.statements[1]
    assert_instance_of Aurora::AST::VarRef, block.result_expr
  end

  def test_block_lowering_generates_statements
    source = <<~AUR
      fn apply(xs: i32[]) -> i32 =
        for x in xs do
          let mut value = x;
          value = value + 1;
          value
        end
    AUR

    cpp = Aurora.to_cpp(source)

    assert_includes cpp, "int value = x;"
    assert_includes cpp, "value = value + 1;"
    assert_includes cpp, "for (int x : xs)"
  end

  def test_function_level_mutable_assignments
    source = <<~AUR
      fn main() -> i32 =
        let mut x = 0;
        x = x + 1;
        x
    AUR

    cpp = Aurora.to_cpp(source)

    assert_includes cpp, "int x = 0;"
    assert_includes cpp, "x = x + 1;"
    assert_includes cpp, "return x;"
  end
end
