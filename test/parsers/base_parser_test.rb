# frozen_string_literal: true

require_relative "../test_helper"

class TestBaseParser < Minitest::Test
  def setup
    @lexer = CppAst::Lexer.new("foo bar")
    @parser = CppAst::Parsers::BaseParser.new(@lexer)
  end
  
  def test_current_token
    assert_equal :identifier, @parser.current_token.kind
    assert_equal "foo", @parser.current_token.lexeme
  end
  
  def test_peek_token
    assert_equal :identifier, @parser.peek_token.kind
    assert_equal "bar", @parser.peek_token.lexeme
  end
  
  def test_at_end_false
    refute @parser.at_end?
  end
  
  def test_at_end_true
    lexer = CppAst::Lexer.new("")
    parser = CppAst::Parsers::BaseParser.new(lexer)
    
    assert parser.at_end?
  end
  
  def test_advance_raw
    @parser.advance_raw
    assert_equal :identifier, @parser.current_token.kind
    assert_equal "bar", @parser.current_token.lexeme
  end
  
  def test_current_leading_trivia
    assert_equal "", @parser.current_leading_trivia
    @parser.advance_raw
    # После advance, текущий токен "bar" не имеет leading_trivia, 
    # так как пробел был в trailing_trivia предыдущего токена
    assert_equal "", @parser.current_leading_trivia
  end
  
  def test_current_trailing_trivia
    assert_equal " ", @parser.current_trailing_trivia
  end
  
  def test_expect_token_success
    @parser.expect(:identifier)
    assert_equal :identifier, @parser.current_token.kind
    assert_equal "bar", @parser.current_token.lexeme
  end
  
  def test_expect_token_raises_on_mismatch
    error = assert_raises(CppAst::ParseError) do
      @parser.expect(:semicolon)
    end
    
    assert_match /Expected semicolon/, error.message
  end
  
  def test_expect_identifier
    token = @parser.expect_identifier
    
    assert_equal "foo", token.lexeme
    assert_equal :identifier, @parser.current_token.kind
    assert_equal "bar", @parser.current_token.lexeme
  end
end

