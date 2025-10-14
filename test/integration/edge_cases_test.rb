# frozen_string_literal: true

require "test_helper"

class EdgeCasesTest < Minitest::Test
  # Empty files
  def test_empty_file
    source = ""
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_only_whitespace
    source = "   \n\n  "
    program = CppAst.parse(source)
    output = program.to_source
    # Empty program doesn't preserve trivia (known limitation)
    assert_equal "", output
  end
  
  def test_only_comments
    source = "// comment\n"
    program = CppAst.parse(source)
    output = program.to_source
    # Comments alone create empty program (trivia not preserved)
    assert_equal "", output
  end
  
  def test_only_block_comment
    source = "/* comment */\n"
    program = CppAst.parse(source)
    output = program.to_source
    # Block comments alone create empty program (trivia not preserved)
    assert_equal "", output
  end
  
  def test_only_preprocessor
    source = "#include <iostream>\n"
    program = CppAst.parse(source)
    output = program.to_source
    # Preprocessor alone creates empty program (trivia not preserved)
    assert_equal "", output
  end
  
  # Line endings
  def test_unix_line_endings
    source = "int main(){\nreturn 0;\n}\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_windows_line_endings
    source = "int main(){\r\nreturn 0;\r\n}\r\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_mixed_line_endings
    source = "int main(){\nreturn 0;\r\n}\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  # Unicode
  def test_unicode_in_comment
    source = "// Комментарий на русском\nint x;\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_unicode_emoji_in_comment
    source = "// 🚀 rocket comment\nint x;\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_unicode_in_string
    source = "s = \"Привет\";\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_unicode_emoji_in_string
    source = "s = \"Hello 🌍\";\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  # Deep nesting
  def test_deeply_nested_blocks
    source = "{\n{\n{\n{\nx = 1;\n}\n}\n}\n}\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_deeply_nested_expressions
    source = "x = 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10;\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  # Whitespace variations
  def test_multiple_spaces
    source = "int     x     =     42;\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_tabs
    source = "int\tx\t=\t42;\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  def test_mixed_whitespace
    source = "int  \t x \t = \t 42;\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
  
  # No trailing newline
  def test_no_trailing_newline_statement
    source = "x = 42;"
    program = CppAst.parse(source)
    # Parser doesn't add trailing newline if not present
    output = program.to_source
    assert_equal "x = 42;", output
  end
  
  def test_no_trailing_newline_function
    source = "int main(){ return 0; }"
    program = CppAst.parse(source)
    # Parser doesn't add trailing newline if not present
    output = program.to_source
    assert_equal "int main(){ return 0; }", output
  end
  
  # Special characters in comments
  def test_special_chars_in_comment
    source = "// !@#$%^&*(){}[]<>?/\\\n"
    program = CppAst.parse(source)
    output = program.to_source
    # Comments alone create empty program (trivia not preserved)
    assert_equal "", output
  end
  
  # Very long lines
  def test_very_long_line
    # Create a 1000 character line
    long_ident = "x" * 500
    source = "int #{long_ident} = #{long_ident};\n"
    program = CppAst.parse(source)
    output = program.to_source
    assert_equal source, output
  end
end

