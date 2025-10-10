# frozen_string_literal: true

require_relative "../test_helper"

class TestTernary < Minitest::Test
  def test_simple_ternary
    condition = CppAst::Nodes::Identifier.new(name: "flag")
    true_expr = CppAst::Nodes::NumberLiteral.new(value: "1")
    false_expr = CppAst::Nodes::NumberLiteral.new(value: "0")
    node = CppAst::Nodes::TernaryExpression.new(
      condition: condition,
      true_expression: true_expr,
      false_expression: false_expr
    )
    
    assert_equal "flag?1:0", node.to_source
  end
  
  def test_with_spacing
    condition = CppAst::Nodes::Identifier.new(name: "flag")
    true_expr = CppAst::Nodes::NumberLiteral.new(value: "1")
    false_expr = CppAst::Nodes::NumberLiteral.new(value: "0")
    node = CppAst::Nodes::TernaryExpression.new(
      condition: condition,
      true_expression: true_expr,
      false_expression: false_expr,
      question_prefix: " ",
      question_suffix: " ",
      colon_prefix: " ",
      colon_suffix: " "
    )
    
    assert_equal "flag ? 1 : 0", node.to_source
  end
end

