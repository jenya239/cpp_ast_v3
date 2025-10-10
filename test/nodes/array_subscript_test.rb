# frozen_string_literal: true

require_relative "../test_helper"

class TestArraySubscript < Minitest::Test
  def test_simple_subscript
    array = CppAst::Nodes::Identifier.new(name: "arr")
    index = CppAst::Nodes::NumberLiteral.new(value: "0")
    node = CppAst::Nodes::ArraySubscriptExpression.new(
      array: array,
      index: index
    )
    
    assert_equal "arr[0]", node.to_source
  end
  
  def test_with_lbracket_suffix
    array = CppAst::Nodes::Identifier.new(name: "arr")
    index = CppAst::Nodes::NumberLiteral.new(value: "0")
    node = CppAst::Nodes::ArraySubscriptExpression.new(
      array: array,
      index: index,
      lbracket_suffix: " "
    )
    
    assert_equal "arr[ 0]", node.to_source
  end
  
  def test_with_rbracket_prefix
    array = CppAst::Nodes::Identifier.new(name: "arr")
    index = CppAst::Nodes::NumberLiteral.new(value: "0")
    node = CppAst::Nodes::ArraySubscriptExpression.new(
      array: array,
      index: index,
      rbracket_prefix: " "
    )
    
    assert_equal "arr[0 ]", node.to_source
  end
  
  def test_with_expression_index
    array = CppAst::Nodes::Identifier.new(name: "arr")
    i = CppAst::Nodes::Identifier.new(name: "i")
    one = CppAst::Nodes::NumberLiteral.new(value: "1")
    index = CppAst::Nodes::BinaryExpression.new(
      left: i,
      operator: "+",
      right: one,
      operator_prefix: " ",
      operator_suffix: " "
    )
    node = CppAst::Nodes::ArraySubscriptExpression.new(
      array: array,
      index: index
    )
    
    assert_equal "arr[i + 1]", node.to_source
  end
  
  def test_multidimensional
    arr = CppAst::Nodes::Identifier.new(name: "matrix")
    i = CppAst::Nodes::NumberLiteral.new(value: "0")
    first = CppAst::Nodes::ArraySubscriptExpression.new(
      array: arr,
      index: i
    )
    j = CppAst::Nodes::NumberLiteral.new(value: "1")
    second = CppAst::Nodes::ArraySubscriptExpression.new(
      array: first,
      index: j
    )
    
    assert_equal "matrix[0][1]", second.to_source
  end
end

