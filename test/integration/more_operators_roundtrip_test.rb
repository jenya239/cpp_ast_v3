# frozen_string_literal: true

require_relative "../test_helper"

class TestMoreOperatorsRoundtrip < Minitest::Test
  # Comparison operators
  def test_less_than
    assert_roundtrip "result = a < b;\n"
  end
  
  def test_greater_than
    assert_roundtrip "result = a > b;\n"
  end
  
  def test_less_equals
    assert_roundtrip "result = a <= b;\n"
  end
  
  def test_greater_equals
    assert_roundtrip "result = a >= b;\n"
  end
  
  def test_equals_equals
    assert_roundtrip "result = a == b;\n"
  end
  
  def test_not_equals
    assert_roundtrip "result = a != b;\n"
  end
  
  # Logical operators
  def test_logical_and
    assert_roundtrip "result = a && b;\n"
  end
  
  def test_logical_or
    assert_roundtrip "result = a || b;\n"
  end
  
  # Bitwise operators
  def test_bitwise_and
    assert_roundtrip "result = a & b;\n"
  end
  
  def test_bitwise_or
    assert_roundtrip "result = a | b;\n"
  end
  
  def test_bitwise_xor
    assert_roundtrip "result = a ^ b;\n"
  end
  
  def test_left_shift
    assert_roundtrip "result = a << b;\n"
  end
  
  def test_right_shift
    assert_roundtrip "result = a >> b;\n"
  end
  
  # Compound assignment
  def test_plus_equals
    assert_roundtrip "a += b;\n"
  end
  
  def test_minus_equals
    assert_roundtrip "a -= b;\n"
  end
  
  def test_asterisk_equals
    assert_roundtrip "a *= b;\n"
  end
  
  def test_slash_equals
    assert_roundtrip "a /= b;\n"
  end
  
  # Precedence tests
  def test_comparison_precedence
    assert_roundtrip "result = a + b < c;\n"
  end
  
  def test_logical_precedence
    assert_roundtrip "result = a || b && c;\n"
  end
  
  def test_complex_expression
    assert_roundtrip "result = (a + b) * c == d && e < f;\n"
  end
end

