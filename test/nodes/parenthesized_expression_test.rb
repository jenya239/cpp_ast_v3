# frozen_string_literal: true

require_relative "../test_helper"

class TestParenthesizedExpression < Minitest::Test
  def test_simple_parenthesized_expression
    inner = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::ParenthesizedExpression.new(expression: inner)
    
    assert_equal "(x)", node.to_source
  end
  
  def test_with_spacing_before_paren
    inner = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::ParenthesizedExpression.new(
      expression: inner,
      open_paren_suffix: " "
    )
    
    assert_equal "( x)", node.to_source
  end
  
  def test_with_spacing_after_paren
    inner = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::ParenthesizedExpression.new(
      expression: inner,
      close_paren_prefix: " "
    )
    
    assert_equal "(x )", node.to_source
  end
  
  def test_with_spacing_both_sides
    inner = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::ParenthesizedExpression.new(
      expression: inner,
      open_paren_suffix: " ",
      close_paren_prefix: " "
    )
    
    assert_equal "( x )", node.to_source
  end
  
  def test_nested_expression
    x = CppAst::Nodes::Identifier.new(name: "x")
    y = CppAst::Nodes::NumberLiteral.new(value: "42")
    binary = CppAst::Nodes::BinaryExpression.new(
      left: x,
      operator: "+",
      operator_prefix: " ",
      operator_suffix: " ",
      right: y
    )
    node = CppAst::Nodes::ParenthesizedExpression.new(expression: binary)
    
    assert_equal "(x + 42)", node.to_source
  end
  
  def test_doubly_nested
    x = CppAst::Nodes::Identifier.new(name: "x")
    inner = CppAst::Nodes::ParenthesizedExpression.new(expression: x)
    outer = CppAst::Nodes::ParenthesizedExpression.new(expression: inner)
    
    assert_equal "((x))", outer.to_source
  end
end

