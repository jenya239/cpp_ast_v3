# frozen_string_literal: true

require_relative "../test_helper"

class TestExpressionNodes < Minitest::Test
  # Identifier tests
  def test_identifier_to_source
    node = CppAst::Nodes::Identifier.new(name: "foo")
    assert_equal "foo", node.to_source
  end
  
  def test_identifier_does_not_include_trivia
    node = CppAst::Nodes::Identifier.new(name: "foo")
    refute_includes node.to_source, "\n"
    refute_includes node.to_source, " "
  end
  
  def test_identifier_equality
    node1 = CppAst::Nodes::Identifier.new(name: "foo")
    node2 = CppAst::Nodes::Identifier.new(name: "foo")
    node3 = CppAst::Nodes::Identifier.new(name: "bar")
    
    assert_equal node1, node2
    refute_equal node1, node3
  end
  
  # NumberLiteral tests
  def test_number_literal_to_source
    node = CppAst::Nodes::NumberLiteral.new(value: "42")
    assert_equal "42", node.to_source
  end
  
  def test_number_literal_with_different_formats
    assert_equal "0x1A", CppAst::Nodes::NumberLiteral.new(value: "0x1A").to_source
    assert_equal "3.14", CppAst::Nodes::NumberLiteral.new(value: "3.14").to_source
    assert_equal "1e10", CppAst::Nodes::NumberLiteral.new(value: "1e10").to_source
  end
  
  # BinaryExpression tests
  def test_binary_expression_simple
    left = CppAst::Nodes::Identifier.new(name: "x")
    right = CppAst::Nodes::NumberLiteral.new(value: "42")
    node = CppAst::Nodes::BinaryExpression.new(
      left: left,
      operator: "+",
      right: right
    )
    
    assert_equal "x+42", node.to_source
  end
  
  def test_binary_expression_with_spacing
    left = CppAst::Nodes::Identifier.new(name: "x")
    right = CppAst::Nodes::NumberLiteral.new(value: "42")
    node = CppAst::Nodes::BinaryExpression.new(
      left: left,
      operator: "+",
      operator_prefix: " ",
      operator_suffix: " ",
      right: right
    )
    
    assert_equal "x + 42", node.to_source
  end
  
  def test_binary_expression_nested
    # (x + 1) + 2
    inner_left = CppAst::Nodes::Identifier.new(name: "x")
    inner_right = CppAst::Nodes::NumberLiteral.new(value: "1")
    inner = CppAst::Nodes::BinaryExpression.new(
      left: inner_left,
      operator: "+",
      operator_prefix: " ",
      operator_suffix: " ",
      right: inner_right
    )
    
    outer_right = CppAst::Nodes::NumberLiteral.new(value: "2")
    outer = CppAst::Nodes::BinaryExpression.new(
      left: inner,
      operator: "+",
      operator_prefix: " ",
      operator_suffix: " ",
      right: outer_right
    )
    
    assert_equal "x + 1 + 2", outer.to_source
  end
  
  # UnaryExpression tests
  def test_unary_expression_prefix
    operand = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "!",
      operand: operand,
      prefix: true
    )
    
    assert_equal "!x", node.to_source
  end
  
  def test_unary_expression_postfix
    operand = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "++",
      operand: operand,
      prefix: false
    )
    
    assert_equal "x++", node.to_source
  end
  
  def test_unary_expression_with_spacing
    operand = CppAst::Nodes::Identifier.new(name: "flag")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "!",
      operator_suffix: " ",
      operand: operand,
      prefix: true
    )
    
    assert_equal "! flag", node.to_source
  end
end

