# frozen_string_literal: true

require_relative "../test_helper"

class TestUnaryParser < Minitest::Test
  def parse_expression(source)
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ExpressionParser.new(lexer)
    expr, trailing = parser.parse_expression
    [expr, trailing]
  end
  
  # Prefix operators
  def test_prefix_minus
    expr, _trailing = parse_expression("-x")
    
    assert_instance_of CppAst::Nodes::UnaryExpression, expr
    assert_equal "-", expr.operator
    assert_equal true, expr.prefix
    assert_instance_of CppAst::Nodes::Identifier, expr.operand
  end
  
  def test_prefix_plus
    expr, _trailing = parse_expression("+x")
    
    assert_equal "+", expr.operator
    assert_equal true, expr.prefix
  end
  
  def test_prefix_not
    expr, _trailing = parse_expression("!flag")
    
    assert_equal "!", expr.operator
    assert_equal true, expr.prefix
  end
  
  def test_prefix_tilde
    expr, _trailing = parse_expression("~bits")
    
    assert_equal "~", expr.operator
    assert_equal true, expr.prefix
  end
  
  def test_prefix_increment
    expr, _trailing = parse_expression("++counter")
    
    assert_equal "++", expr.operator
    assert_equal true, expr.prefix
  end
  
  def test_prefix_decrement
    expr, _trailing = parse_expression("--counter")
    
    assert_equal "--", expr.operator
    assert_equal true, expr.prefix
  end
  
  def test_prefix_dereference
    expr, _trailing = parse_expression("*ptr")
    
    assert_equal "*", expr.operator
    assert_equal true, expr.prefix
  end
  
  def test_prefix_address_of
    expr, _trailing = parse_expression("&var")
    
    assert_equal "&", expr.operator
    assert_equal true, expr.prefix
  end
  
  # Postfix operators
  def test_postfix_increment
    expr, _trailing = parse_expression("counter++")
    
    assert_instance_of CppAst::Nodes::UnaryExpression, expr
    assert_equal "++", expr.operator
    assert_equal false, expr.prefix
  end
  
  def test_postfix_decrement
    expr, _trailing = parse_expression("counter--")
    
    assert_equal "--", expr.operator
    assert_equal false, expr.prefix
  end
  
  # Chained unary
  def test_double_negative
    # Note: "--x" is decrement, not double negative
    # For double negative, need space: "- -x"
    expr, _trailing = parse_expression("- -x")
    
    assert_instance_of CppAst::Nodes::UnaryExpression, expr
    assert_equal "-", expr.operator
    assert_instance_of CppAst::Nodes::UnaryExpression, expr.operand
    assert_equal "-", expr.operand.operator
  end
  
  def test_not_not
    expr, _trailing = parse_expression("!!flag")
    
    assert_equal "!", expr.operator
    assert_equal "!", expr.operand.operator
  end
  
  def test_dereference_address
    expr, _trailing = parse_expression("*&var")
    
    assert_equal "*", expr.operator
    assert_equal "&", expr.operand.operator
  end
  
  # Mixed with binary
  def test_unary_in_binary
    expr, _trailing = parse_expression("-x + y")
    
    assert_instance_of CppAst::Nodes::BinaryExpression, expr
    assert_equal "+", expr.operator
    assert_instance_of CppAst::Nodes::UnaryExpression, expr.left
    assert_equal "-", expr.left.operator
  end
  
  def test_both_sides_unary
    expr, _trailing = parse_expression("-x + -y")
    
    assert_instance_of CppAst::Nodes::BinaryExpression, expr
    assert_instance_of CppAst::Nodes::UnaryExpression, expr.left
    assert_instance_of CppAst::Nodes::UnaryExpression, expr.right
  end
  
  # Roundtrip tests
  def test_roundtrip_prefix
    source = "-x"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_postfix
    source = "counter++"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_with_spaces
    source = "- x"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_complex
    source = "!flag + -value * ++counter"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
end

