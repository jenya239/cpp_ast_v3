# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora"

class AuroraControlFlowStatementTest < Minitest::Test
  def test_if_statement_generates_cpp_if
    source = <<~AUR
      fn adjust(value: i32) -> i32 =
        let mut total = value;
        if total > 10 then {
          total = total - 5;
        } else {
          total = total + 5;
        }
        total
    AUR

    ast = Aurora.parse(source)
    block = ast.declarations.first.body

    assert_instance_of Aurora::AST::Block, block
    assert_equal 3, block.stmts.size
    assert_instance_of Aurora::AST::VariableDecl, block.stmts.first

    if_stmt = block.stmts[1]
    assert_instance_of Aurora::AST::ExprStmt, if_stmt
    assert_instance_of Aurora::AST::IfExpr, if_stmt.expr
    assert_instance_of Aurora::AST::BlockExpr, if_stmt.expr.then_branch
    assert_instance_of Aurora::AST::BlockExpr, if_stmt.expr.else_branch

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "if (total > 10)"
    assert_includes cpp, "total = total - 5;"
    assert_includes cpp, "else"
    assert_includes cpp, "total = total + 5;"
  end

  def test_while_statement_generates_cpp_while
    source = <<~AUR
      fn countdown(n: i32) -> i32 =
        let mut value = n;
        while value > 0 do
          value = value - 1;
          0
        end;
        value
    AUR

    cpp = Aurora.to_cpp(source)

    assert_includes cpp, "while (value > 0)"
    assert_includes cpp, "value = value - 1;"
  end

  def test_return_statement_in_block
    source = <<~AUR
      fn pick(value: i32) -> i32 =
        let mut answer = value;
        if value > 0 then {
          return value;
        };
        answer
    AUR

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "if (value > 0)"
    assert_includes cpp, "return value;"
  end

  def test_break_and_continue_inside_loop
    source = <<~AUR
      fn first_positive(xs: i32[]) -> i32 =
        let mut found = -1;
        for x in xs do
          if x < 0 then do
            continue;
            0
          end;
          found = x;
          break;
          0
        end;
        found
    AUR

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "continue;"
    assert_includes cpp, "break;"
  end

  def test_return_without_expression_in_void_function
    source = <<~AUR
      fn reset() -> void =
        if true then {
          return;
        } else {
          return;
        }
    AUR

    cpp = Aurora.to_cpp(source)
    assert_includes cpp, "return;"
  end
end
