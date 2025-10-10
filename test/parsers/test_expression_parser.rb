# frozen_string_literal: true

require_relative "../test_helper"

class TestExpressionParser < Minitest::Test
  def parse_expression(source)
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ExpressionParser.new(lexer)
    expr, trailing = parser.parse_expression
    [expr, trailing]
  end
  
  # Primary expressions
  def test_parse_identifier
    expr, trailing = parse_expression("foo")
    
    assert_instance_of CppAst::Nodes::Identifier, expr
    assert_equal "foo", expr.name
    assert_equal "", trailing
  end
  
  def test_parse_identifier_with_trailing
    expr, trailing = parse_expression("foo ")
    
    assert_equal "foo", expr.name
    assert_equal " ", trailing
  end
  
  def test_parse_number
    expr, trailing = parse_expression("42")
    
    assert_instance_of CppAst::Nodes::NumberLiteral, expr
    assert_equal "42", expr.value
    assert_equal "", trailing
  end
  
  def test_parse_number_with_trailing
    expr, trailing = parse_expression("42\n")
    
    assert_equal "42", expr.value
    assert_equal "\n", trailing
  end
  
  # Binary expressions
  def test_parse_binary_expression_no_spaces
    expr, _ = parse_expression("x+42")
    
    assert_instance_of CppAst::Nodes::BinaryExpression, expr
    assert_equal "x", expr.left.name
    assert_equal "+", expr.operator
    assert_equal "42", expr.right.value
    assert_equal "", expr.operator_prefix
    assert_equal "", expr.operator_suffix
  end
  
  def test_parse_binary_expression_with_spaces
    expr, _ = parse_expression("x + 42")
    
    assert_equal " ", expr.operator_prefix
    assert_equal " ", expr.operator_suffix
  end
  
  def test_parse_binary_expression_with_newlines
    expr, _ = parse_expression("x\n+\n42")
    
    assert_equal "\n", expr.operator_prefix
    assert_equal "\n", expr.operator_suffix
  end
  
  def test_binary_expression_roundtrip_no_spaces
    source = "x+42"
    expr, trailing = parse_expression(source)
    
    assert_equal source, expr.to_source + trailing
  end
  
  def test_binary_expression_roundtrip_with_spaces
    source = "x + 42"
    expr, trailing = parse_expression(source)
    
    assert_equal source, expr.to_source + trailing
  end
  
  def test_binary_expression_roundtrip_with_trailing
    source = "x + 42 "
    expr, trailing = parse_expression(source)
    
    assert_equal source, expr.to_source + trailing
  end
  
  # Operator precedence
  def test_addition_precedence
    expr, _ = parse_expression("a+b+c")
    
    # Should parse as (a+b)+c (left-to-right)
    assert_instance_of CppAst::Nodes::BinaryExpression, expr
    assert_equal "+", expr.operator
    assert_instance_of CppAst::Nodes::BinaryExpression, expr.left
    assert_equal "c", expr.right.name
  end
  
  def test_multiplication_precedence
    expr, _ = parse_expression("a+b*c")
    
    # Should parse as a+(b*c)
    assert_equal "+", expr.operator
    assert_equal "a", expr.left.name
    assert_instance_of CppAst::Nodes::BinaryExpression, expr.right
    assert_equal "*", expr.right.operator
  end
  
  def test_assignment_right_associative
    expr, _ = parse_expression("a=b=c")
    
    # Should parse as a=(b=c) (right-to-left)
    assert_equal "=", expr.operator
    assert_equal "a", expr.left.name
    assert_instance_of CppAst::Nodes::BinaryExpression, expr.right
    assert_equal "=", expr.right.operator
  end
  
  # Complex expressions
  def test_complex_expression_roundtrip
    source = "result = x + y * 2"
    expr, trailing = parse_expression(source)
    
    assert_equal source, expr.to_source + trailing
  end
end

