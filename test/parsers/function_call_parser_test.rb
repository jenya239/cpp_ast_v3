# frozen_string_literal: true

require_relative "../test_helper"

class TestFunctionCallParser < Minitest::Test
  def parse_expression(source)
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ExpressionParser.new(lexer)
    expr, trailing = parser.parse_expression
    [expr, trailing]
  end
  
  def test_simple_no_args
    expr, _trailing = parse_expression("foo()")
    
    assert_instance_of CppAst::Nodes::FunctionCallExpression, expr
    assert_equal "foo", expr.callee.name
    assert_equal 0, expr.arguments.length
  end
  
  def test_one_argument
    expr, _trailing = parse_expression("foo(x)")
    
    assert_equal 1, expr.arguments.length
    assert_instance_of CppAst::Nodes::Identifier, expr.arguments[0]
    assert_equal "x", expr.arguments[0].name
  end
  
  def test_multiple_arguments
    expr, _trailing = parse_expression("add(x, y)")
    
    assert_equal 2, expr.arguments.length
    assert_equal "x", expr.arguments[0].name
    assert_equal "y", expr.arguments[1].name
  end
  
  def test_three_arguments
    expr, _trailing = parse_expression("func(a, b, c)")
    
    assert_equal 3, expr.arguments.length
  end
  
  def test_expression_as_argument
    expr, _trailing = parse_expression("foo(x + y)")
    
    assert_instance_of CppAst::Nodes::BinaryExpression, expr.arguments[0]
    assert_equal "+", expr.arguments[0].operator
  end
  
  def test_multiple_expression_arguments
    expr, _trailing = parse_expression("calc(x + 1, y * 2)")
    
    assert_equal 2, expr.arguments.length
    assert_instance_of CppAst::Nodes::BinaryExpression, expr.arguments[0]
    assert_instance_of CppAst::Nodes::BinaryExpression, expr.arguments[1]
  end
  
  def test_nested_call
    expr, _trailing = parse_expression("outer(inner())")
    
    assert_instance_of CppAst::Nodes::FunctionCallExpression, expr
    assert_equal 1, expr.arguments.length
    assert_instance_of CppAst::Nodes::FunctionCallExpression, expr.arguments[0]
  end
  
  def test_chained_calls
    expr, _trailing = parse_expression("foo()()")
    
    # foo() returns something, and that something is called again
    assert_instance_of CppAst::Nodes::FunctionCallExpression, expr
    assert_instance_of CppAst::Nodes::FunctionCallExpression, expr.callee
  end
  
  def test_call_with_postfix
    expr, _trailing = parse_expression("foo(x++)")
    
    assert_instance_of CppAst::Nodes::UnaryExpression, expr.arguments[0]
    assert_equal "++", expr.arguments[0].operator
  end
  
  def test_call_with_prefix
    expr, _trailing = parse_expression("foo(--x)")
    
    assert_instance_of CppAst::Nodes::UnaryExpression, expr.arguments[0]
    assert_equal "--", expr.arguments[0].operator
  end
  
  # Roundtrip tests
  def test_roundtrip_no_args
    source = "foo()"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_one_arg
    source = "foo(x)"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_multiple_args
    source = "add(x, y)"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_with_spaces
    source = "foo( x , y )"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_nested
    source = "outer(inner(x))"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_complex
    source = "calculate(a + b, c * d, foo())"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
end

