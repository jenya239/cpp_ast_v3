# frozen_string_literal: true

require_relative "../test_helper"

class BlockParserTest < Minitest::Test
  def parse_block(source, leading_trivia = "")
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::StatementParser.new(lexer)
    parser.parse_statement(leading_trivia)
  end
  
  def test_parse_empty_block
    block, trailing = parse_block("{}")
    
    assert_instance_of CppAst::Nodes::BlockStatement, block
    assert_equal 0, block.statements.size
    assert_equal "", trailing
  end
  
  def test_parse_block_with_one_statement
    block, _trailing = parse_block("{ x; }")
    
    assert_instance_of CppAst::Nodes::BlockStatement, block
    assert_equal 1, block.statements.size
    assert_instance_of CppAst::Nodes::ExpressionStatement, block.statements[0]
  end
  
  def test_parse_block_with_multiple_statements
    block, _trailing = parse_block("{ x; y; }")
    
    assert_equal 2, block.statements.size
  end
  
  def test_block_roundtrip_simple
    source = "{ x; }"
    block, trailing = parse_block(source)
    
    assert_equal source, block.to_source + trailing
  end
  
  def test_block_roundtrip_with_newlines
    source = "{\n  x;\n  y;\n}"
    block, trailing = parse_block(source)
    
    assert_equal source, block.to_source + trailing
  end
  
  def test_nested_blocks
    source = "{ { x; } }"
    block, trailing = parse_block(source)
    
    assert_equal source, block.to_source + trailing
  end
end

