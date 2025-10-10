# frozen_string_literal: true

require_relative "../test_helper"

class TestParenthesizedRoundtrip < Minitest::Test
  def test_simple_parenthesized_statement
    assert_roundtrip "x = (y);\n"
  end
  
  def test_parenthesized_changes_precedence
    assert_roundtrip "result = (a + b) * c;\n"
  end
  
  def test_nested_parentheses
    assert_roundtrip "x = ((y + z));\n"
  end
  
  def test_multiple_parentheses
    assert_roundtrip "result = (a + b) * (c + d);\n"
  end
  
  def test_with_spaces
    assert_roundtrip "x = ( a + b ) * c;\n"
  end
  
  def test_complex_expression
    assert_roundtrip "result = ((a + b) * (c - d)) / (e + f);\n"
  end
  
  def test_parentheses_in_return
    assert_roundtrip "return (x + y);\n"
  end
end

