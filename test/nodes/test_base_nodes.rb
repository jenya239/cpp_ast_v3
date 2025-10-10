# frozen_string_literal: true

require_relative "../test_helper"

class TestBaseNodes < Minitest::Test
  def test_node_is_abstract
    node = CppAst::Nodes::Node.new
    
    assert_raises(NotImplementedError) do
      node.to_source
    end
  end
  
  def test_expression_is_abstract
    expr = CppAst::Nodes::Expression.new
    
    assert_raises(NotImplementedError) do
      expr.to_source
    end
  end
  
  def test_statement_has_leading_trivia
    stmt = CppAst::Nodes::Statement.new(leading_trivia: "  ")
    assert_equal "  ", stmt.leading_trivia
  end
  
  def test_statement_default_leading_trivia
    stmt = CppAst::Nodes::Statement.new
    assert_equal "", stmt.leading_trivia
  end
end

