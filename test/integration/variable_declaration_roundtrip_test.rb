require_relative '../test_helper'

class VariableDeclarationRoundtripTest < Minitest::Test
  def test_simple_int_declaration
    assert_roundtrip "int x = 42;"
  end

  def test_simple_without_init
    assert_roundtrip "int x;"
  end

  def test_const_int_declaration
    assert_roundtrip "const int x = 10;"
  end

  def test_pointer_declaration
    assert_roundtrip "int* ptr = nullptr;"
  end

  def test_const_pointer_declaration
    assert_roundtrip "const int* ptr = nullptr;"
  end

  def test_auto_declaration
    assert_roundtrip "auto x = foo();"
  end

  def test_multiple_declarators
    assert_roundtrip "int x = 1, y = 2;"
  end

  def test_multiple_declarators_mixed
    assert_roundtrip "int x, y = 2, z;"
  end

  def test_float_declaration
    assert_roundtrip "float f = 3.14;"
  end

  def test_double_declaration
    assert_roundtrip "double d = 2.718;"
  end

  def test_char_declaration
    assert_roundtrip "char c = 'a';"
  end

  def test_bool_declaration
    assert_roundtrip "bool flag = true;"
  end

  def test_unsigned_int
    assert_roundtrip "unsigned int x = 42;"
  end

  def test_long_long
    assert_roundtrip "long long big = 9999999999;"
  end

  def test_static_variable
    assert_roundtrip "static int counter = 0;"
  end

  def test_with_whitespace
    assert_roundtrip "int  x  =  42 ;"
  end
end

