# frozen_string_literal: true

require_relative "../test_helper"

class LiteralsRoundtripTest < Minitest::Test
  # String literals
  def test_simple_string
    assert_roundtrip 'x = "hello";'
  end
  
  def test_string_with_spaces
    assert_roundtrip 'x = "hello world";'
  end
  
  def test_string_with_escapes
    assert_roundtrip 'x = "hello\\nworld";'
  end
  
  def test_string_with_quotes
    assert_roundtrip 'x = "hello \\"world\\"";'
  end
  
  def test_empty_string
    assert_roundtrip 'x = "";'
  end
  
  # Character literals
  def test_simple_char
    assert_roundtrip "x = 'a';"
  end
  
  def test_char_with_escape
    assert_roundtrip "x = '\\n';"
  end
  
  def test_char_with_hex
    assert_roundtrip "x = '\\x41';"
  end
  
  # Boolean and nullptr
  def test_true
    assert_roundtrip "x = true;"
  end
  
  def test_false
    assert_roundtrip "x = false;"
  end
  
  def test_nullptr
    assert_roundtrip "x = nullptr;"
  end
  
  # Combined
  def test_string_concatenation
    assert_roundtrip 'x = "hello" + "world";'
  end
  
  def test_string_in_if
    assert_roundtrip 'if (x) y = "test";'
  end
end

