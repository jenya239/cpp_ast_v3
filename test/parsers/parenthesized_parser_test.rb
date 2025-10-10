# frozen_string_literal: true

require_relative "../test_helper"

class TestParenthesizedParser < Minitest::Test
  def parse_expression(source)
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ExpressionParser.new(lexer)
    expr, trailing = parser.parse_expression
    [expr, trailing]
  end
  
  def test_simple_parenthesized
    expr, trailing = parse_expression("(x)")
    
    assert_instance_of CppAst::Nodes::ParenthesizedExpression, expr
    assert_instance_of CppAst::Nodes::Identifier, expr.expression
    assert_equal "x", expr.expression.name
    assert_equal "", trailing
  end
  
  def test_with_spaces_inside
    expr, _trailing = parse_expression("( x )")
    
    assert_equal " ", expr.open_paren_suffix
    assert_equal " ", expr.close_paren_prefix
  end
  
  def test_nested_parentheses
    expr, _trailing = parse_expression("((x))")
    
    assert_instance_of CppAst::Nodes::ParenthesizedExpression, expr
    assert_instance_of CppAst::Nodes::ParenthesizedExpression, expr.expression
    assert_instance_of CppAst::Nodes::Identifier, expr.expression.expression
  end
  
  def test_parenthesized_binary_expression
    expr, _trailing = parse_expression("(x + y)")
    
    assert_instance_of CppAst::Nodes::ParenthesizedExpression, expr
    assert_instance_of CppAst::Nodes::BinaryExpression, expr.expression
  end
  
  def test_changes_precedence
    # Without parens: x + y * z is x + (y * z)
    # With parens: (x + y) * z
    expr, _trailing = parse_expression("(x + y) * z")
    
    assert_instance_of CppAst::Nodes::BinaryExpression, expr
    assert_equal "*", expr.operator
    assert_instance_of CppAst::Nodes::ParenthesizedExpression, expr.left
    assert_instance_of CppAst::Nodes::BinaryExpression, expr.left.expression
    assert_equal "+", expr.left.expression.operator
  end
  
  def test_roundtrip_simple
    source = "(x)"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_with_spaces
    source = "( x + y )"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_complex
    source = "((a + b) * c)"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_precedence
    source = "(x + y) * z"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
end

