# frozen_string_literal: true

require_relative "../test_helper"

class TestUnaryExpression < Minitest::Test
  def test_prefix_minus
    operand = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "-",
      operand: operand,
      prefix: true
    )
    
    assert_equal "-x", node.to_source
  end
  
  def test_prefix_plus
    operand = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "+",
      operand: operand,
      prefix: true
    )
    
    assert_equal "+x", node.to_source
  end
  
  def test_prefix_not
    operand = CppAst::Nodes::Identifier.new(name: "flag")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "!",
      operand: operand,
      prefix: true
    )
    
    assert_equal "!flag", node.to_source
  end
  
  def test_prefix_tilde
    operand = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "~",
      operand: operand,
      prefix: true
    )
    
    assert_equal "~x", node.to_source
  end
  
  def test_prefix_increment
    operand = CppAst::Nodes::Identifier.new(name: "counter")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "++",
      operand: operand,
      prefix: true
    )
    
    assert_equal "++counter", node.to_source
  end
  
  def test_prefix_decrement
    operand = CppAst::Nodes::Identifier.new(name: "counter")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "--",
      operand: operand,
      prefix: true
    )
    
    assert_equal "--counter", node.to_source
  end
  
  def test_prefix_dereference
    operand = CppAst::Nodes::Identifier.new(name: "ptr")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "*",
      operand: operand,
      prefix: true
    )
    
    assert_equal "*ptr", node.to_source
  end
  
  def test_prefix_address_of
    operand = CppAst::Nodes::Identifier.new(name: "var")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "&",
      operand: operand,
      prefix: true
    )
    
    assert_equal "&var", node.to_source
  end
  
  def test_postfix_increment
    operand = CppAst::Nodes::Identifier.new(name: "counter")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "++",
      operand: operand,
      prefix: false
    )
    
    assert_equal "counter++", node.to_source
  end
  
  def test_postfix_decrement
    operand = CppAst::Nodes::Identifier.new(name: "counter")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "--",
      operand: operand,
      prefix: false
    )
    
    assert_equal "counter--", node.to_source
  end
  
  def test_with_operator_suffix
    operand = CppAst::Nodes::Identifier.new(name: "x")
    node = CppAst::Nodes::UnaryExpression.new(
      operator: "-",
      operand: operand,
      operator_suffix: " ",
      prefix: true
    )
    
    assert_equal "- x", node.to_source
  end
end

