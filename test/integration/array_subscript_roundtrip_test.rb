# frozen_string_literal: true

require_relative "../test_helper"

class TestArraySubscriptRoundtrip < Minitest::Test
  def test_simple_subscript
    assert_roundtrip "result = arr[0];\n"
  end
  
  def test_expression_index
    assert_roundtrip "result = arr[i + 1];\n"
  end
  
  def test_multidimensional
    assert_roundtrip "result = matrix[i][j];\n"
  end
  
  def test_with_member_access
    assert_roundtrip "result = obj.arr[0];\n"
  end
  
  def test_in_function_call
    assert_roundtrip "result = foo(arr[i]);\n"
  end
  
  def test_return_subscript
    assert_roundtrip "return arr[0];\n"
  end
end

