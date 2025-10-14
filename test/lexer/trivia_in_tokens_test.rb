# frozen_string_literal: true

require "test_helper"

class TriviaInTokensTest < Minitest::Test
  def test_token_with_leading_trivia
    lexer = CppAst::Lexer.new("  x")
    tokens = lexer.tokenize
    
    assert_equal :identifier, tokens[0].kind
    assert_equal "x", tokens[0].lexeme
    assert_equal "  ", tokens[0].leading_trivia
    assert_equal "", tokens[0].trailing_trivia
  end
  
  def test_token_with_trailing_trivia
    lexer = CppAst::Lexer.new("x ")
    tokens = lexer.tokenize
    
    assert_equal :identifier, tokens[0].kind
    assert_equal "x", tokens[0].lexeme
    assert_equal "", tokens[0].leading_trivia
    assert_equal " ", tokens[0].trailing_trivia
  end
  
  def test_multiple_tokens_with_trivia
    lexer = CppAst::Lexer.new("x = 42;\n")
    tokens = lexer.tokenize
    
    # x
    assert_equal "x", tokens[0].lexeme
    assert_equal "", tokens[0].leading_trivia
    assert_equal " ", tokens[0].trailing_trivia
    
    # =
    assert_equal "=", tokens[1].lexeme
    assert_equal "", tokens[1].leading_trivia
    assert_equal " ", tokens[1].trailing_trivia
    
    # 42
    assert_equal "42", tokens[2].lexeme
    assert_equal "", tokens[2].leading_trivia
    assert_equal "", tokens[2].trailing_trivia
    
    # ;
    assert_equal ";", tokens[3].lexeme
    assert_equal "", tokens[3].leading_trivia
    assert_equal "\n", tokens[3].trailing_trivia
  end
  
  def test_leading_trivia_accumulation
    lexer = CppAst::Lexer.new("  \n  x")
    tokens = lexer.tokenize
    
    assert_equal :identifier, tokens[0].kind
    assert_equal "  \n  ", tokens[0].leading_trivia
  end
  
  def test_comment_in_trailing_trivia
    lexer = CppAst::Lexer.new("x // comment\n")
    tokens = lexer.tokenize
    
    assert_equal :identifier, tokens[0].kind
    assert_equal " // comment\n", tokens[0].trailing_trivia
  end
  
  def test_block_comment_in_trivia
    lexer = CppAst::Lexer.new("x /* comment */ y")
    tokens = lexer.tokenize
    
    # x
    assert_equal "x", tokens[0].lexeme
    assert_equal " /* comment */ ", tokens[0].trailing_trivia
    
    # y
    assert_equal "y", tokens[1].lexeme
    assert_equal "", tokens[1].leading_trivia
  end
  
  def test_preprocessor_in_leading_trivia
    lexer = CppAst::Lexer.new("#include <iostream>\nint x;")
    tokens = lexer.tokenize
    
    # int
    assert_equal :keyword_int, tokens[0].kind
    assert_equal "#include <iostream>\n", tokens[0].leading_trivia
  end
  
  def test_eof_token_with_accumulated_trivia
    lexer = CppAst::Lexer.new("x;\n\n  ")
    tokens = lexer.tokenize
    
    eof_token = tokens[-1]
    assert_equal :eof, eof_token.kind
    # First \n goes to semicolon trailing, rest to EOF leading
    assert_equal "\n  ", eof_token.leading_trivia
    assert_equal "", eof_token.trailing_trivia
  end
  
  def test_no_trivia_tokens_in_output
    lexer = CppAst::Lexer.new("  x  =  42  ;  \n")
    tokens = lexer.tokenize
    
    # Should only have: x, =, 42, ;, eof
    assert_equal 5, tokens.length
    
    # No whitespace/newline/comment tokens
    tokens.each do |token|
      refute CppAst::Token.trivia?(token.kind), 
        "Found trivia token #{token.kind} in output"
    end
  end
  
  def test_trivia_preserves_exact_whitespace
    source = "int\t\tx\t =\t42 ;\n"
    lexer = CppAst::Lexer.new(source)
    tokens = lexer.tokenize
    
    # Reconstruct source from tokens
    reconstructed = tokens[0..-2].map do |token|
      token.leading_trivia + token.lexeme + token.trailing_trivia
    end.join
    reconstructed += tokens[-1].leading_trivia  # EOF leading
    
    assert_equal source, reconstructed
  end
  
  def test_multiline_comment_in_trivia
    lexer = CppAst::Lexer.new("x /*\nmultiline\n*/ y")
    tokens = lexer.tokenize
    
    assert_equal "x", tokens[0].lexeme
    assert_equal " /*\nmultiline\n*/ ", tokens[0].trailing_trivia
  end
  
  def test_consecutive_comments
    lexer = CppAst::Lexer.new("x // comment1\n// comment2\ny")
    tokens = lexer.tokenize
    
    # x
    assert_equal "x", tokens[0].lexeme
    assert_equal " // comment1\n", tokens[0].trailing_trivia
    
    # y
    assert_equal "y", tokens[1].lexeme
    assert_equal "// comment2\n", tokens[1].leading_trivia
  end
end

