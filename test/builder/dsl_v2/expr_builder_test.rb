#!/usr/bin/env ruby
# frozen_string_literal: true

require "test/unit"
require_relative "../../../lib/cpp_ast"
require_relative "../../../lib/cpp_ast/builder/dsl_v2_simple"

class ExprBuilderTest < Test::Unit::TestCase
  include CppAst::Builder::DSLv2Improved

  def test_identifier_creation
    # Test identifier creation
    id_expr = id(:x)
    assert_not_nil id_expr
    assert_equal "x", id_expr.node.name
  end

  def test_literal_creation
    # Test literal creation
    int_lit = int(42)
    assert_not_nil int_lit
    assert_equal "42", int_lit.node.value
    
    float_lit = float(3.14)
    assert_not_nil float_lit
    assert_equal "3.14", float_lit.node.value
    
    string_lit = string("hello")
    assert_not_nil string_lit
    assert_equal "hello", string_lit.node.value
    
    bool_lit = bool(true)
    assert_not_nil bool_lit
    assert_equal true, bool_lit.node.value
    
    char_lit = char('a')
    assert_not_nil char_lit
    assert_equal 'a', char_lit.node.value
  end

  def test_binary_operators
    # Test binary operators
    a = id(:a)
    b = id(:b)
    
    # Addition
    add_expr = a + b
    assert_not_nil add_expr
    assert_equal "+", add_expr.node.operator
    
    # Subtraction
    sub_expr = a - b
    assert_not_nil sub_expr
    assert_equal "-", sub_expr.node.operator
    
    # Multiplication
    mul_expr = a * b
    assert_not_nil mul_expr
    assert_equal "*", mul_expr.node.operator
    
    # Division
    div_expr = a / b
    assert_not_nil div_expr
    assert_equal "/", div_expr.node.operator
  end

  def test_comparison_operators
    # Test comparison operators
    a = id(:a)
    b = id(:b)
    
    # Equality
    eq_expr = a == b
    assert_not_nil eq_expr
    assert_equal "==", eq_expr.node.operator
    
    # Inequality
    ne_expr = a != b
    assert_not_nil ne_expr
    assert_equal "!=", ne_expr.node.operator
    
    # Less than
    lt_expr = a < b
    assert_not_nil lt_expr
    assert_equal "<", lt_expr.node.operator
    
    # Less than or equal
    le_expr = a <= b
    assert_not_nil le_expr
    assert_equal "<=", le_expr.node.operator
    
    # Greater than
    gt_expr = a > b
    assert_not_nil gt_expr
    assert_equal ">", gt_expr.node.operator
    
    # Greater than or equal
    ge_expr = a >= b
    assert_not_nil ge_expr
    assert_equal ">=", ge_expr.node.operator
  end

  def test_unary_operators
    # Test unary operators
    x = id(:x)
    
    # Negation
    neg_expr = -x
    assert_not_nil neg_expr
    assert_equal "-", neg_expr.node.operator
    assert_equal true, neg_expr.node.prefix
    
    # Logical not
    not_expr = !x
    assert_not_nil not_expr
    assert_equal "!", not_expr.node.operator
    assert_equal true, not_expr.node.prefix
    
    # Postfix increment
    inc_expr = x.increment
    assert_not_nil inc_expr
    assert_equal "++", inc_expr.node.operator
    assert_equal false, inc_expr.node.prefix
    
    # Postfix decrement
    dec_expr = x.decrement
    assert_not_nil dec_expr
    assert_equal "--", dec_expr.node.operator
    assert_equal false, dec_expr.node.prefix
  end

  def test_method_calls
    # Test method calls
    obj = id(:obj)
    method_call = obj.call(:method, int(42), string("hello"))
    
    assert_not_nil method_call
    assert_equal 2, method_call.node.arguments.size
    assert_equal ", ", method_call.node.argument_separators.join
  end

  def test_member_access
    # Test member access
    obj = id(:obj)
    member_access = obj.member(:field)
    
    assert_not_nil member_access
    assert_equal ".", member_access.node.operator
    assert_equal "field", member_access.node.member_name
  end

  def test_array_access
    # Test array access
    arr = id(:arr)
    index = int(0)
    array_access = arr[index]
    
    assert_not_nil array_access
    assert_equal arr.node, array_access.node.array
    assert_equal index.node, array_access.node.index
  end

  def test_dereference_and_address
    # Test dereference and address operators
    ptr = id(:ptr)
    
    # Dereference
    deref_expr = deref(ptr)
    assert_not_nil deref_expr
    assert_equal "*", deref_expr.node.operator
    assert_equal true, deref_expr.node.prefix
    
    # Address of
    addr_expr = address_of(ptr)
    assert_not_nil addr_expr
    assert_equal "&", addr_expr.node.operator
    assert_equal true, addr_expr.node.prefix
  end

  def test_cast_expression
    # Test cast expression
    expr = int(42)
    type = t.f32
    cast_expr = cast(type, expr)
    
    assert_not_nil cast_expr
    assert_equal "float", cast_expr.node.type
    assert_equal expr.node, cast_expr.node.expression
  end

  def test_ternary_operator
    # Test ternary operator
    condition = id(:x) > int(0)
    true_expr = int(1)
    false_expr = int(0)
    ternary_expr = ternary(condition, true_expr, false_expr)
    
    assert_not_nil ternary_expr
    assert_equal condition.node, ternary_expr.node.condition
    assert_equal true_expr.node, ternary_expr.node.true_expression
    assert_equal false_expr.node, ternary_expr.node.false_expression
  end

  def test_sizeof_expression
    # Test sizeof expression
    type = t.i32
    sizeof_expr = sizeof(type)
    
    assert_not_nil sizeof_expr
    assert_equal "int", sizeof_expr.node.type
    
    # Test sizeof with expression
    expr = id(:x)
    sizeof_expr_expr = sizeof(expr)
    
    assert_not_nil sizeof_expr_expr
    assert_equal expr.node, sizeof_expr_expr.node.expression
  end

  def test_new_delete_expressions
    # Test new expression
    type = t.i32
    new_expr = new(type, int(42))
    
    assert_not_nil new_expr
    assert_equal "int", new_expr.node.type
    assert_equal 1, new_expr.node.arguments.size
    
    # Test delete expression
    expr = id(:ptr)
    delete_expr = delete(expr)
    
    assert_not_nil delete_expr
    assert_equal expr.node, delete_expr.node.expression
  end

  def test_lambda_expression
    # Test lambda expression
    params = [[:i32, :x], [:i32, :y]]
    body = id(:x) + id(:y)
    lambda_expr = lambda_expr(params, body)
    
    assert_not_nil lambda_expr
    assert_equal params, lambda_expr.node.parameters
    assert_equal body.node, lambda_expr.node.body
  end

  def test_function_call
    # Test function call
    callee = id(:func)
    args = [int(1), int(2), int(3)]
    call_expr = call(callee, *args)
    
    assert_not_nil call_expr
    assert_equal callee.node, call_expr.node.callee
    assert_equal 3, call_expr.node.arguments.size
    assert_equal 2, call_expr.node.argument_separators.size
  end

  def test_member_access_helper
    # Test member access helper
    obj = id(:obj)
    field_name = :field
    member_access = member(obj, field_name)
    
    assert_not_nil member_access
    assert_equal obj.node, member_access.node.object
    assert_equal ".", member_access.node.operator
    assert_equal "field", member_access.node.member_name
  end

  def test_array_access_helper
    # Test array access helper
    array = id(:arr)
    index = int(5)
    array_access = array_access(array, index)
    
    assert_not_nil array_access
    assert_equal array.node, array_access.node.array
    assert_equal index.node, array_access.node.index
  end

  def test_pipe_operator
    # Test pipe operator
    obj = id(:x)
    pipe_expr = obj.pipe(:sqrt)
    
    assert_not_nil pipe_expr
    assert_equal "sqrt", pipe_expr.node.callee.member_name
  end

  def test_assignment
    # Test assignment
    left = id(:x)
    right = int(42)
    assign_expr = left.assign(right)
    
    assert_not_nil assign_expr
    assert_equal left.node, assign_expr.left
    assert_equal "=", assign_expr.operator
    assert_equal right.node, assign_expr.right
  end

  def test_complex_expressions
    # Test complex expressions
    a = id(:a)
    b = id(:b)
    c = id(:c)
    
    # Complex arithmetic: (a + b) * c
    complex_expr = (a + b) * c
    assert_not_nil complex_expr
    assert_equal "*", complex_expr.node.operator
    
    # Method chaining: obj.method1().method2()
    obj = id(:obj)
    chained = obj.call(:method1).call(:method2)
    assert_not_nil chained
  end

  def test_expression_to_node_conversion
    # Test conversion to underlying node
    expr = id(:x) + int(42)
    node = expr.to_node
    
    assert_not_nil node
    assert_equal "+", node.operator
  end

  def test_expression_to_source
    # Test conversion to source
    expr = id(:x) + int(42)
    source = expr.to_source
    
    assert_not_nil source
    assert_kind_of String, source
  end
end
