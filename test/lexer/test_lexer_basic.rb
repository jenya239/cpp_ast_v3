# frozen_string_literal: true

require_relative "../test_helper"

class TestLexerBasic < Minitest::Test
  def test_lex_identifier
    lexer = CppAst::Lexer.new("foo")
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.size
    assert_equal :identifier, tokens[0].kind
    assert_equal "foo", tokens[0].lexeme
    assert_equal :eof, tokens[1].kind
  end
  
  def test_lex_with_whitespace
    lexer = CppAst::Lexer.new("foo bar")
    tokens = lexer.tokenize
    
    assert_equal 4, tokens.size
    assert_equal :identifier, tokens[0].kind
    assert_equal "foo", tokens[0].lexeme
    assert_equal :whitespace, tokens[1].kind
    assert_equal " ", tokens[1].lexeme
    assert_equal :identifier, tokens[2].kind
    assert_equal "bar", tokens[2].lexeme
    assert_equal :eof, tokens[3].kind
  end
  
  def test_lex_operators
    lexer = CppAst::Lexer.new("x = 42;")
    tokens = lexer.tokenize
    
    kinds = tokens.map(&:kind)
    assert_equal [:identifier, :whitespace, :equals, :whitespace, 
                  :number, :semicolon, :eof], kinds
  end
  
  def test_lex_with_newline
    lexer = CppAst::Lexer.new("x = 1;\ny = 2;")
    tokens = lexer.tokenize
    
    # Check that newline is preserved
    newline_token = tokens.find { |t| t.kind == :newline }
    assert newline_token, "Should have newline token"
    assert_equal "\n", newline_token.lexeme
  end
  
  def test_lex_line_comment
    lexer = CppAst::Lexer.new("x = 42; // comment")
    tokens = lexer.tokenize
    
    comment_token = tokens.find { |t| t.kind == :comment }
    assert comment_token
    assert_equal "// comment", comment_token.lexeme
  end
  
  def test_lex_position_tracking
    lexer = CppAst::Lexer.new("foo")
    tokens = lexer.tokenize
    
    assert_equal 1, tokens[0].line
    assert_equal 0, tokens[0].column
  end
  
  def test_lex_multiline_position_tracking
    lexer = CppAst::Lexer.new("foo\nbar")
    tokens = lexer.tokenize
    
    foo_token = tokens[0]
    bar_token = tokens[2]  # after newline
    
    assert_equal 1, foo_token.line
    assert_equal 2, bar_token.line
  end
end

