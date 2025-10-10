# frozen_string_literal: true

require_relative "../test_helper"

class TestLexerBasic < Minitest::Test
  def test_lex_identifier
    lexer = CppAst::Lexer.new("foo")
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.size
    assert_equal :identifier, tokens[0].kind
    assert_equal "foo", tokens[0].lexeme
    assert_equal "", tokens[0].leading_trivia
    assert_equal "", tokens[0].trailing_trivia
    assert_equal :eof, tokens[1].kind
  end
  
  def test_lex_with_whitespace
    lexer = CppAst::Lexer.new("foo bar")
    tokens = lexer.tokenize
    
    # Now whitespace is in trailing/leading trivia, not separate tokens
    assert_equal 3, tokens.size
    assert_equal :identifier, tokens[0].kind
    assert_equal "foo", tokens[0].lexeme
    assert_equal " ", tokens[0].trailing_trivia
    assert_equal :identifier, tokens[1].kind
    assert_equal "bar", tokens[1].lexeme
    assert_equal :eof, tokens[2].kind
  end
  
  def test_lex_operators
    lexer = CppAst::Lexer.new("x = 42;")
    tokens = lexer.tokenize
    
    # Trivia is now attached to tokens, not separate
    kinds = tokens.map(&:kind)
    assert_equal [:identifier, :equals, :number, :semicolon, :eof], kinds
    
    # Check trivia
    assert_equal " ", tokens[0].trailing_trivia
    assert_equal " ", tokens[1].trailing_trivia
  end
  
  def test_lex_with_newline
    lexer = CppAst::Lexer.new("x = 1;\ny = 2;")
    tokens = lexer.tokenize
    
    # Newline is now in trailing trivia of semicolon
    semicolon_token = tokens.find { |t| t.kind == :semicolon && t.trailing_trivia.include?("\n") }
    assert semicolon_token, "Should have semicolon with newline in trailing"
    assert_equal "\n", semicolon_token.trailing_trivia
  end
  
  def test_lex_line_comment
    lexer = CppAst::Lexer.new("x = 42; // comment")
    tokens = lexer.tokenize
    
    # Comment is now in trailing trivia of semicolon
    semicolon_token = tokens.find { |t| t.kind == :semicolon }
    assert semicolon_token
    assert_equal " // comment", semicolon_token.trailing_trivia
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
    bar_token = tokens[1]
    
    assert_equal 1, foo_token.line
    assert_equal 2, bar_token.line
    assert_equal "\n", foo_token.trailing_trivia
  end
  
  def test_leading_trivia
    lexer = CppAst::Lexer.new("  foo")
    tokens = lexer.tokenize
    
    assert_equal 2, tokens.size
    assert_equal "  ", tokens[0].leading_trivia
    assert_equal "foo", tokens[0].lexeme
  end
  
  def test_trailing_trivia_with_comment_and_newline
    lexer = CppAst::Lexer.new("foo // comment\nbar")
    tokens = lexer.tokenize
    
    assert_equal 3, tokens.size
    assert_equal "foo", tokens[0].lexeme
    assert_equal " // comment\n", tokens[0].trailing_trivia
    assert_equal "bar", tokens[1].lexeme
  end
  
  def test_block_comment_in_trivia
    lexer = CppAst::Lexer.new("foo /* comment */ bar")
    tokens = lexer.tokenize
    
    assert_equal 3, tokens.size
    assert_equal " /* comment */ ", tokens[0].trailing_trivia
  end
  
  def test_preprocessor_in_leading_trivia
    lexer = CppAst::Lexer.new("#include <stdio.h>\nint x;")
    tokens = lexer.tokenize
    
    int_token = tokens.find { |t| t.kind == :keyword_int }
    assert int_token
    assert int_token.leading_trivia.include?("#include <stdio.h>")
  end
  
  def test_multiple_whitespace_lines
    lexer = CppAst::Lexer.new("foo\n\n\nbar")
    tokens = lexer.tokenize
    
    assert_equal 3, tokens.size
    assert_equal "foo", tokens[0].lexeme
    # Only first newline goes to trailing
    assert_equal "\n", tokens[0].trailing_trivia
    # Rest go to leading of bar
    assert_equal "\n\n", tokens[1].leading_trivia
    assert_equal "bar", tokens[1].lexeme
  end
end

