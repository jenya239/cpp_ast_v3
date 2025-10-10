# frozen_string_literal: true

require_relative "../test_helper"

class TestTernaryRoundtrip < Minitest::Test
  def test_simple_ternary
    assert_roundtrip "result = flag ? 1 : 0;\n"
  end
  
  def test_no_spaces
    assert_roundtrip "result = flag?1:0;\n"
  end
  
  def test_nested_ternary
    assert_roundtrip "result = a ? b ? 1 : 2 : 3;\n"
  end
  
  def test_with_complex_condition
    assert_roundtrip "result = x > y ? x : y;\n"
  end
  
  def test_in_return
    assert_roundtrip "return flag ? x : y;\n"
  end
end

