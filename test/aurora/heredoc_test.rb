# frozen_string_literal: true

require_relative "../test_helper"

class HeredocTest < Minitest::Test
  def test_heredoc_basic
    source = <<~'AUR'
      fn main() -> i32 = do
        let text = <<END
Hello
World
END
        0
      end
    AUR

    lexer = Aurora::Parser::Lexer.new(source)
    tokens = lexer.tokenize

    # Find the STRING_LITERAL token
    string_token = tokens.find { |t| t.type == :STRING_LITERAL }
    refute_nil string_token
    assert_equal "Hello\nWorld", string_token.value
  end

  def test_heredoc_with_indent_stripping
    source = <<~'AUR'
      fn main() -> i32 = do
        let text = <<~END
          Hello
          World
        END
        0
      end
    AUR

    lexer = Aurora::Parser::Lexer.new(source)
    tokens = lexer.tokenize

    string_token = tokens.find { |t| t.type == :STRING_LITERAL }
    refute_nil string_token
    assert_equal "Hello\nWorld", string_token.value
  end

  def test_heredoc_preserves_relative_indentation
    source = <<~'AUR'
      fn main() -> i32 = do
        let sql = <<~SQL
          SELECT *
          FROM users
          WHERE active = true
            AND age > 18
          ORDER BY name
        SQL
        0
      end
    AUR

    lexer = Aurora::Parser::Lexer.new(source)
    tokens = lexer.tokenize

    string_token = tokens.find { |t| t.type == :STRING_LITERAL }
    refute_nil string_token

    expected = "SELECT *\nFROM users\nWHERE active = true\n  AND age > 18\nORDER BY name"
    assert_equal expected, string_token.value
  end

  def test_heredoc_without_tilde_preserves_all_indentation
    source = <<~'AUR'
      fn main() -> i32 = do
        let text = <<END
    Indented
  Less indent
      More indent
        END
        0
      end
    AUR

    lexer = Aurora::Parser::Lexer.new(source)
    tokens = lexer.tokenize

    string_token = tokens.find { |t| t.type == :STRING_LITERAL }
    refute_nil string_token

    expected = "  Indented\nLess indent\n    More indent"
    assert_equal expected, string_token.value
  end

  def test_heredoc_empty_lines
    source = <<~'AUR'
      fn main() -> i32 = do
        let text = <<~END
          First line

          Third line
        END
        0
      end
    AUR

    lexer = Aurora::Parser::Lexer.new(source)
    tokens = lexer.tokenize

    string_token = tokens.find { |t| t.type == :STRING_LITERAL }
    refute_nil string_token
    assert_equal "First line\n\nThird line", string_token.value
  end

  def test_heredoc_single_line
    source = <<~'AUR'
      fn main() -> i32 = do
        let text = <<~END
          Single line
        END
        0
      end
    AUR

    lexer = Aurora::Parser::Lexer.new(source)
    tokens = lexer.tokenize

    string_token = tokens.find { |t| t.type == :STRING_LITERAL }
    refute_nil string_token
    assert_equal "Single line", string_token.value
  end

  def test_multiple_heredocs
    source = <<~'AUR'
      fn main() -> i32 = do
        let text1 = <<~END1
          First heredoc
        END1
        let text2 = <<~END2
          Second heredoc
        END2
        0
      end
    AUR

    lexer = Aurora::Parser::Lexer.new(source)
    tokens = lexer.tokenize

    string_tokens = tokens.select { |t| t.type == :STRING_LITERAL }
    assert_equal 2, string_tokens.size
    assert_equal "First heredoc", string_tokens[0].value
    assert_equal "Second heredoc", string_tokens[1].value
  end
end
