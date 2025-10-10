# frozen_string_literal: true

require_relative "../test_helper"

class TestMemberAccessParser < Minitest::Test
  def parse_expression(source)
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ExpressionParser.new(lexer)
    expr, trailing = parser.parse_expression
    [expr, trailing]
  end
  
  # Dot operator
  def test_dot_access
    expr, _trailing = parse_expression("obj.field")
    
    assert_instance_of CppAst::Nodes::MemberAccessExpression, expr
    assert_equal ".", expr.operator
    assert_equal "obj", expr.object.name
    assert_equal "field", expr.member.name
  end
  
  # Arrow operator
  def test_arrow_access
    expr, _trailing = parse_expression("ptr->field")
    
    assert_equal "->", expr.operator
    assert_equal "ptr", expr.object.name
    assert_equal "field", expr.member.name
  end
  
  # Scope resolution
  def test_scope_resolution
    expr, _trailing = parse_expression("Class::method")
    
    assert_equal "::", expr.operator
    assert_equal "Class", expr.object.name
    assert_equal "method", expr.member.name
  end
  
  # Chained access
  def test_chained_dot
    expr, _trailing = parse_expression("a.b.c")
    
    assert_instance_of CppAst::Nodes::MemberAccessExpression, expr
    assert_equal "c", expr.member.name
    assert_instance_of CppAst::Nodes::MemberAccessExpression, expr.object
    assert_equal "b", expr.object.member.name
    assert_equal "a", expr.object.object.name
  end
  
  def test_mixed_operators
    expr, _trailing = parse_expression("ptr->obj.field")
    
    assert_equal ".", expr.operator
    assert_equal "->", expr.object.operator
  end
  
  # Combined with function calls
  def test_method_call
    expr, _trailing = parse_expression("obj.method()")
    
    assert_instance_of CppAst::Nodes::FunctionCallExpression, expr
    assert_instance_of CppAst::Nodes::MemberAccessExpression, expr.callee
    assert_equal "method", expr.callee.member.name
  end
  
  def test_method_call_with_args
    expr, _trailing = parse_expression("obj.method(x, y)")
    
    assert_instance_of CppAst::Nodes::FunctionCallExpression, expr
    assert_equal 2, expr.arguments.length
  end
  
  def test_chained_calls
    expr, _trailing = parse_expression("obj.foo().bar()")
    
    assert_instance_of CppAst::Nodes::FunctionCallExpression, expr
    assert_equal "bar", expr.callee.member.name
  end
  
  # Roundtrip tests
  def test_roundtrip_dot
    source = "obj.field"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_arrow
    source = "ptr->field"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_scope
    source = "Class::method"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_chained
    source = "a.b.c"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_method_call
    source = "obj.method()"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_complex
    source = "ptr->obj.method(x, y)"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
end

