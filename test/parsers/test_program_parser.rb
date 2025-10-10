# frozen_string_literal: true

require_relative "../test_helper"

class TestProgramParser < Minitest::Test
  def parse_program(source)
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ProgramParser.new(lexer)
    parser.parse
  end
  
  # Basic tests
  def test_parse_empty_program
    program = parse_program("")
    
    assert_equal 0, program.statements.size
    assert_equal 0, program.statement_trailings.size
  end
  
  def test_parse_single_statement
    source = "x = 42;\n"
    program = parse_program(source)
    
    assert_equal 1, program.statements.size
    assert_instance_of CppAst::Nodes::ExpressionStatement, program.statements[0]
    assert_equal ["\n"], program.statement_trailings
  end
  
  def test_parse_multiple_statements
    source = "x = 1;\ny = 2;\n"
    program = parse_program(source)
    
    assert_equal 2, program.statements.size
    assert_equal ["\n", "\n"], program.statement_trailings
  end
  
  # Roundtrip tests
  def test_program_roundtrip_single_statement
    source = "x = 42;\n"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
  
  def test_program_roundtrip_multiple_statements
    source = "x = 1;\ny = 2;\n"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
  
  def test_program_roundtrip_with_indentation
    source = "  x = 42;\n  y = 100;\n"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
  
  def test_program_roundtrip_blank_lines
    source = "x = 1;\n\ny = 2;\n"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
  
  def test_program_roundtrip_with_comments
    source = "x = 42; // comment\ny = 1;\n"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
  
  def test_program_roundtrip_return_statement
    source = "x = 42;\nreturn x;\n"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
  
  def test_program_roundtrip_complex
    source = "result = x + y * 2;\nreturn result;\n"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
  
  # Edge cases
  def test_program_no_trailing_newline
    source = "x = 42;"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
  
  def test_program_leading_whitespace
    source = "\nx = 42;\n"
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
  
  def test_program_trailing_whitespace
    source = "x = 42;\n  "
    program = parse_program(source)
    
    assert_equal source, program.to_source
  end
end

