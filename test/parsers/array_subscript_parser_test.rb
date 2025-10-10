# frozen_string_literal: true

require_relative "../test_helper"

class TestArraySubscriptParser < Minitest::Test
  def parse_expression(source)
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ExpressionParser.new(lexer)
    expr, trailing = parser.parse_expression
    [expr, trailing]
  end
  
  def test_simple_subscript
    expr, _trailing = parse_expression("arr[0]")
    
    assert_instance_of CppAst::Nodes::ArraySubscriptExpression, expr
    assert_equal "arr", expr.array.name
    assert_equal "0", expr.index.value
  end
  
  def test_expression_index
    expr, _trailing = parse_expression("arr[i + 1]")
    
    assert_instance_of CppAst::Nodes::BinaryExpression, expr.index
  end
  
  def test_multidimensional
    expr, _trailing = parse_expression("matrix[0][1]")
    
    assert_instance_of CppAst::Nodes::ArraySubscriptExpression, expr
    assert_instance_of CppAst::Nodes::ArraySubscriptExpression, expr.array
    assert_equal "1", expr.index.value
    assert_equal "0", expr.array.index.value
  end
  
  def test_with_member_access
    expr, _trailing = parse_expression("obj.arr[0]")
    
    assert_instance_of CppAst::Nodes::ArraySubscriptExpression, expr
    assert_instance_of CppAst::Nodes::MemberAccessExpression, expr.array
  end
  
  def test_roundtrip_simple
    source = "arr[0]"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
  
  def test_roundtrip_multidimensional
    source = "matrix[i][j]"
    expr, trailing = parse_expression(source)
    assert_equal source, expr.to_source + trailing
  end
end

