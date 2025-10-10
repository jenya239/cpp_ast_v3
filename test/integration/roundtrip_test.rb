# frozen_string_literal: true

require_relative "../test_helper"

class TestRoundtrip < Minitest::Test
  # Simple assignments
  def test_simple_assignment
    assert_roundtrip "x = 42;\n"
  end
  
  def test_multiple_assignments
    assert_roundtrip "x = 1;\ny = 2;\nz = 3;\n"
  end
  
  # With indentation
  def test_with_indentation
    assert_roundtrip "  x = 42;\n  y = 100;\n"
  end
  
  def test_mixed_indentation
    assert_roundtrip "x = 1;\n  y = 2;\nz = 3;\n"
  end
  
  # With blank lines
  def test_with_blank_lines
    assert_roundtrip "x = 1;\n\ny = 2;\n"
  end
  
  def test_multiple_blank_lines
    assert_roundtrip "x = 1;\n\n\ny = 2;\n"
  end
  
  # With comments
  def test_with_line_comment
    assert_roundtrip "x = 42; // comment\n"
  end
  
  def test_with_multiple_comments
    assert_roundtrip "x = 1; // first\ny = 2; // second\n"
  end
  
  # Complex expressions
  def test_complex_expression
    assert_roundtrip "result = x + y * 2;\n"
  end
  
  def test_nested_expression
    assert_roundtrip "result = a + b * c + d;\n"
  end
  
  def test_expression_with_spacing
    assert_roundtrip "result = x + y * 2;\n"
  end
  
  # Return statements
  def test_return_statement
    assert_roundtrip "return x + 42;\n"
  end
  
  def test_return_with_complex_expr
    assert_roundtrip "return x + y * 2;\n"
  end
  
  def test_mixed_statements
    assert_roundtrip "x = 42;\nreturn x;\n"
  end
  
  # Edge cases
  def test_no_trailing_newline
    assert_roundtrip "x = 42;"
  end
  
  def test_only_whitespace_no_statements
    assert_roundtrip ""
  end
  
  def test_leading_whitespace
    assert_roundtrip "\nx = 42;\n"
  end
  
  def test_trailing_whitespace
    assert_roundtrip "x = 42;\n  "
  end
  
  # Real-world scenarios
  def test_real_world_simple_function_body
    source = <<~CPP.chomp
      x = 42;
      y = x + 1;
      return y;
    CPP
    assert_roundtrip source
  end
  
  def test_real_world_with_comments_and_blank_lines
    source = <<~CPP.chomp
      // Initialize variables
      x = 42;
      y = 100;
      
      // Calculate result
      result = x + y;
      return result;
    CPP
    assert_roundtrip source
  end
end

