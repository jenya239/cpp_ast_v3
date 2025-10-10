# frozen_string_literal: true

require_relative "../test_helper"

class TestStatementNodes < Minitest::Test
  # ExpressionStatement tests
  def test_expression_statement_without_trivia
    expr = CppAst::Nodes::Identifier.new(name: "foo")
    stmt = CppAst::Nodes::ExpressionStatement.new(expression: expr)
    
    assert_equal "foo;", stmt.to_source
  end
  
  def test_expression_statement_with_leading_trivia
    expr = CppAst::Nodes::Identifier.new(name: "foo")
    stmt = CppAst::Nodes::ExpressionStatement.new(
      leading_trivia: "  ",
      expression: expr
    )
    
    assert_equal "  foo;", stmt.to_source
  end
  
  def test_expression_statement_with_binary_expression
    left = CppAst::Nodes::Identifier.new(name: "x")
    right = CppAst::Nodes::NumberLiteral.new(value: "42")
    expr = CppAst::Nodes::BinaryExpression.new(
      left: left,
      operator: "=",
      operator_prefix: " ",
      operator_suffix: " ",
      right: right
    )
    stmt = CppAst::Nodes::ExpressionStatement.new(expression: expr)
    
    assert_equal "x = 42;", stmt.to_source
  end
  
  # ReturnStatement tests
  def test_return_statement_without_trivia
    expr = CppAst::Nodes::NumberLiteral.new(value: "42")
    stmt = CppAst::Nodes::ReturnStatement.new(expression: expr)
    
    assert_equal "return 42;", stmt.to_source
  end
  
  def test_return_statement_with_keyword_suffix
    expr = CppAst::Nodes::NumberLiteral.new(value: "42")
    stmt = CppAst::Nodes::ReturnStatement.new(
      expression: expr,
      keyword_suffix: " "
    )
    
    assert_equal "return 42;", stmt.to_source
  end
  
  def test_return_statement_with_leading_trivia
    expr = CppAst::Nodes::Identifier.new(name: "x")
    stmt = CppAst::Nodes::ReturnStatement.new(
      leading_trivia: "  ",
      expression: expr,
      keyword_suffix: " "
    )
    
    assert_equal "  return x;", stmt.to_source
  end
  
  # Program tests
  def test_program_empty
    program = CppAst::Nodes::Program.new(
      statements: [],
      statement_trailings: []
    )
    
    assert_equal "", program.to_source
  end
  
  def test_program_single_statement
    expr = CppAst::Nodes::Identifier.new(name: "foo")
    stmt = CppAst::Nodes::ExpressionStatement.new(expression: expr)
    
    program = CppAst::Nodes::Program.new(
      statements: [stmt],
      statement_trailings: ["\n"]
    )
    
    assert_equal "foo;\n", program.to_source
  end
  
  def test_program_multiple_statements
    expr1 = CppAst::Nodes::Identifier.new(name: "x")
    stmt1 = CppAst::Nodes::ExpressionStatement.new(expression: expr1)
    
    expr2 = CppAst::Nodes::Identifier.new(name: "y")
    stmt2 = CppAst::Nodes::ExpressionStatement.new(expression: expr2)
    
    program = CppAst::Nodes::Program.new(
      statements: [stmt1, stmt2],
      statement_trailings: ["\n", "\n"]
    )
    
    assert_equal "x;\ny;\n", program.to_source
  end
  
  def test_program_preserves_blank_lines
    expr1 = CppAst::Nodes::Identifier.new(name: "x")
    stmt1 = CppAst::Nodes::ExpressionStatement.new(expression: expr1)
    
    expr2 = CppAst::Nodes::Identifier.new(name: "y")
    stmt2 = CppAst::Nodes::ExpressionStatement.new(expression: expr2)
    
    program = CppAst::Nodes::Program.new(
      statements: [stmt1, stmt2],
      statement_trailings: ["\n\n", "\n"]
    )
    
    assert_equal "x;\n\ny;\n", program.to_source
  end
end

