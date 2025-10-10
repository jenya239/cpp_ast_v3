# frozen_string_literal: true

require_relative "../test_helper"

class TestToken < Minitest::Test
  def test_token_creation
    token = CppAst::Token.new(kind: :identifier, lexeme: "foo", line: 1, column: 0)
    
    assert_equal :identifier, token.kind
    assert_equal "foo", token.lexeme
    assert_equal 1, token.line
    assert_equal 0, token.column
  end
  
  def test_token_trivia_check_class_method
    assert CppAst::Token.trivia?(:whitespace)
    assert CppAst::Token.trivia?(:comment)
    assert CppAst::Token.trivia?(:newline)
    refute CppAst::Token.trivia?(:identifier)
    refute CppAst::Token.trivia?(:number)
  end
  
  def test_token_trivia_check_instance_method
    whitespace_token = CppAst::Token.new(kind: :whitespace, lexeme: " ", line: 1, column: 0)
    identifier_token = CppAst::Token.new(kind: :identifier, lexeme: "foo", line: 1, column: 1)
    
    assert whitespace_token.trivia?
    refute identifier_token.trivia?
  end
  
  def test_token_to_s
    token = CppAst::Token.new(kind: :identifier, lexeme: "foo", line: 1, column: 5)
    
    assert_equal 'Token(identifier, "foo", 1:5)', token.to_s
  end
  
  def test_token_with_leading_trivia
    token = CppAst::Token.new(kind: :identifier, lexeme: "foo", line: 1, column: 5, leading_trivia: "  ")
    
    assert_equal "  ", token.leading_trivia
    assert_equal "", token.trailing_trivia
  end
  
  def test_token_with_trailing_trivia
    token = CppAst::Token.new(kind: :identifier, lexeme: "foo", line: 1, column: 0, trailing_trivia: " ")
    
    assert_equal "", token.leading_trivia
    assert_equal " ", token.trailing_trivia
  end
  
  def test_token_with_both_trivia
    token = CppAst::Token.new(
      kind: :identifier, 
      lexeme: "foo", 
      line: 1, 
      column: 2, 
      leading_trivia: "  ", 
      trailing_trivia: " // comment\n"
    )
    
    assert_equal "  ", token.leading_trivia
    assert_equal " // comment\n", token.trailing_trivia
  end
  
  def test_token_trivia_modification
    token = CppAst::Token.new(kind: :identifier, lexeme: "foo", line: 1, column: 0)
    
    token.leading_trivia = "/* comment */"
    token.trailing_trivia = "\n"
    
    assert_equal "/* comment */", token.leading_trivia
    assert_equal "\n", token.trailing_trivia
  end
end

