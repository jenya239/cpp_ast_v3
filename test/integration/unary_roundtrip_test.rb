# frozen_string_literal: true

require_relative "../test_helper"

class TestUnaryRoundtrip < Minitest::Test
  # Prefix operators
  def test_prefix_minus
    assert_roundtrip "x = -y;\n"
  end
  
  def test_prefix_plus
    assert_roundtrip "x = +y;\n"
  end
  
  def test_prefix_not
    assert_roundtrip "result = !flag;\n"
  end
  
  def test_prefix_tilde
    assert_roundtrip "result = ~bits;\n"
  end
  
  def test_prefix_increment
    assert_roundtrip "x = ++counter;\n"
  end
  
  def test_prefix_decrement
    assert_roundtrip "x = --counter;\n"
  end
  
  def test_prefix_dereference
    assert_roundtrip "value = *ptr;\n"
  end
  
  def test_prefix_address_of
    assert_roundtrip "ptr = &var;\n"
  end
  
  # Postfix operators
  def test_postfix_increment
    assert_roundtrip "x = counter++;\n"
  end
  
  def test_postfix_decrement
    assert_roundtrip "x = counter--;\n"
  end
  
  def test_postfix_statement
    assert_roundtrip "counter++;\n"
  end
  
  # Mixed expressions
  def test_unary_in_expression
    assert_roundtrip "result = -x + y;\n"
  end
  
  def test_multiple_unary
    assert_roundtrip "result = -x + -y;\n"
  end
  
  def test_unary_with_multiply
    assert_roundtrip "result = -x * y;\n"
  end
  
  def test_precedence_preserved
    assert_roundtrip "result = !flag + value;\n"
  end
  
  # Chained unary
  def test_double_negative_with_space
    assert_roundtrip "x = - -y;\n"
  end
  
  def test_not_not
    assert_roundtrip "x = !!y;\n"
  end
  
  def test_dereference_address
    assert_roundtrip "x = *&y;\n"
  end
  
  # Complex expressions
  def test_complex_with_unary
    assert_roundtrip "result = -a * b + c / -d;\n"
  end
  
  def test_unary_with_parentheses
    assert_roundtrip "result = -(a + b);\n"
  end
  
  def test_prefix_and_postfix
    assert_roundtrip "result = ++a + b--;\n"
  end
  
  # With return
  def test_return_unary
    assert_roundtrip "return -x;\n"
  end
  
  def test_return_postfix
    assert_roundtrip "return counter++;\n"
  end
end

