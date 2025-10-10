# frozen_string_literal: true

require_relative "../test_helper"

class TestNumberLiterals < Minitest::Test
  def tokenize(source)
    lexer = CppAst::Lexer.new(source)
    lexer.tokenize
  end
  
  # Decimal integers
  def test_decimal_integer
    tokens = tokenize("42")
    assert_equal :number, tokens[0].kind
    assert_equal "42", tokens[0].lexeme
  end
  
  # Hexadecimal
  def test_hex_lowercase
    tokens = tokenize("0xff")
    assert_equal :number, tokens[0].kind
    assert_equal "0xff", tokens[0].lexeme
  end
  
  def test_hex_uppercase
    tokens = tokenize("0xFF")
    assert_equal "0xFF", tokens[0].lexeme
  end
  
  def test_hex_mixed
    tokens = tokenize("0x1a2B")
    assert_equal "0x1a2B", tokens[0].lexeme
  end
  
  # Octal
  def test_octal
    tokens = tokenize("0755")
    assert_equal :number, tokens[0].kind
    assert_equal "0755", tokens[0].lexeme
  end
  
  def test_octal_leading_zero
    tokens = tokenize("0123")
    assert_equal "0123", tokens[0].lexeme
  end
  
  # Binary
  def test_binary_lowercase
    tokens = tokenize("0b1010")
    assert_equal :number, tokens[0].kind
    assert_equal "0b1010", tokens[0].lexeme
  end
  
  def test_binary_uppercase
    tokens = tokenize("0B1010")
    assert_equal "0B1010", tokens[0].lexeme
  end
  
  # Floating point
  def test_float_basic
    tokens = tokenize("3.14")
    assert_equal :number, tokens[0].kind
    assert_equal "3.14", tokens[0].lexeme
  end
  
  def test_float_leading_dot
    tokens = tokenize(".5")
    assert_equal ".5", tokens[0].lexeme
  end
  
  def test_float_scientific
    tokens = tokenize("1.0e10")
    assert_equal "1.0e10", tokens[0].lexeme
  end
  
  def test_float_scientific_negative
    tokens = tokenize("1.5e-3")
    assert_equal "1.5e-3", tokens[0].lexeme
  end
  
  def test_float_scientific_positive
    tokens = tokenize("2.0e+5")
    assert_equal "2.0e+5", tokens[0].lexeme
  end
  
  # Suffixes
  def test_unsigned_suffix
    tokens = tokenize("42u")
    assert_equal "42u", tokens[0].lexeme
  end
  
  def test_unsigned_uppercase
    tokens = tokenize("42U")
    assert_equal "42U", tokens[0].lexeme
  end
  
  def test_long_suffix
    tokens = tokenize("42l")
    assert_equal "42l", tokens[0].lexeme
  end
  
  def test_long_uppercase
    tokens = tokenize("42L")
    assert_equal "42L", tokens[0].lexeme
  end
  
  def test_long_long_suffix
    tokens = tokenize("42ll")
    assert_equal "42ll", tokens[0].lexeme
  end
  
  def test_long_long_uppercase
    tokens = tokenize("42LL")
    assert_equal "42LL", tokens[0].lexeme
  end
  
  def test_unsigned_long
    tokens = tokenize("42ul")
    assert_equal "42ul", tokens[0].lexeme
  end
  
  def test_unsigned_long_long
    tokens = tokenize("42ull")
    assert_equal "42ull", tokens[0].lexeme
  end
  
  def test_float_suffix
    tokens = tokenize("3.14f")
    assert_equal "3.14f", tokens[0].lexeme
  end
  
  def test_float_suffix_uppercase
    tokens = tokenize("3.14F")
    assert_equal "3.14F", tokens[0].lexeme
  end
end


