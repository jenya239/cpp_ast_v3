# frozen_string_literal: true

require_relative "../test_helper"

class TestFunctionCallRoundtrip < Minitest::Test
  # Simple calls
  def test_no_args
    assert_roundtrip "result = foo();\n"
  end
  
  def test_one_arg
    assert_roundtrip "result = foo(x);\n"
  end
  
  def test_multiple_args
    assert_roundtrip "result = add(x, y);\n"
  end
  
  def test_three_args
    assert_roundtrip "result = func(a, b, c);\n"
  end
  
  # With expressions
  def test_expression_arg
    assert_roundtrip "result = foo(x + y);\n"
  end
  
  def test_multiple_expression_args
    assert_roundtrip "result = calc(a + b, c * d);\n"
  end
  
  def test_unary_in_arg
    assert_roundtrip "result = foo(-x, !flag);\n"
  end
  
  # Nested calls
  def test_nested_call
    assert_roundtrip "result = outer(inner());\n"
  end
  
  def test_deeply_nested
    assert_roundtrip "result = a(b(c(x)));\n"
  end
  
  def test_multiple_nested
    assert_roundtrip "result = foo(bar(), baz());\n"
  end
  
  # Chained calls
  def test_chained_calls
    assert_roundtrip "result = foo()();\n"
  end
  
  # With postfix
  def test_postfix_in_arg
    assert_roundtrip "result = foo(x++);\n"
  end
  
  def test_postfix_on_result
    assert_roundtrip "result = foo()++;\n"
  end
  
  # In statements
  def test_call_statement
    assert_roundtrip "foo();\n"
  end
  
  def test_call_in_return
    assert_roundtrip "return foo(x, y);\n"
  end
  
  # With spaces
  def test_with_spaces
    assert_roundtrip "result = foo( x , y );\n"
  end
  
  def test_no_space_after_comma
    assert_roundtrip "result = foo(x,y,z);\n"
  end
  
  # Complex expressions
  def test_call_in_binary
    assert_roundtrip "result = foo() + bar();\n"
  end
  
  def test_call_with_complex_args
    assert_roundtrip "result = process((a + b) * c, foo(x));\n"
  end
  
  def test_parenthesized_call
    assert_roundtrip "result = (foo());\n"
  end
end

