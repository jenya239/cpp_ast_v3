# frozen_string_literal: true

require_relative "../test_helper"

class BlockStatementTest < Minitest::Test
  def test_empty_block
    block = CppAst::Nodes::BlockStatement.new(
      statements: [],
      statement_trailings: []
    )
    
    assert_equal "{}", block.to_source
  end
  
  def test_block_with_one_statement
    expr = CppAst::Nodes::Identifier.new(name: "x")
    stmt = CppAst::Nodes::ExpressionStatement.new(expression: expr)
    
    block = CppAst::Nodes::BlockStatement.new(
      statements: [stmt],
      statement_trailings: ["\n"]
    )
    
    assert_equal "{x;\n}", block.to_source
  end
  
  def test_block_with_multiple_statements
    stmt1 = CppAst::Nodes::ExpressionStatement.new(
      expression: CppAst::Nodes::Identifier.new(name: "x")
    )
    stmt2 = CppAst::Nodes::ExpressionStatement.new(
      expression: CppAst::Nodes::Identifier.new(name: "y")
    )
    
    block = CppAst::Nodes::BlockStatement.new(
      statements: [stmt1, stmt2],
      statement_trailings: ["\n", "\n"]
    )
    
    assert_equal "{x;\ny;\n}", block.to_source
  end
  
  def test_block_with_whitespace
    expr = CppAst::Nodes::Identifier.new(name: "x")
    stmt = CppAst::Nodes::ExpressionStatement.new(
      leading_trivia: "  ",
      expression: expr
    )
    
    block = CppAst::Nodes::BlockStatement.new(
      statements: [stmt],
      statement_trailings: ["\n"],
      lbrace_suffix: "\n",
      rbrace_prefix: ""
    )
    
    assert_equal "{\n  x;\n}", block.to_source
  end
end

