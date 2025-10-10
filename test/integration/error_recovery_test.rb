# frozen_string_literal: true

require_relative "../test_helper"

class ErrorRecoveryTest < Minitest::Test
  def test_recovers_from_parse_error
    source = <<~CPP
      int x = 5;
      virtual inline void foo();
      int y = 10;
    CPP
    
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ProgramParser.new(lexer)
    program = parser.parse
    
    # Should have 3 statements: x=5, error, y=10
    assert_equal 3, program.statements.size
    
    # First statement should be valid
    assert_instance_of CppAst::Nodes::VariableDeclaration, program.statements[0]
    
    # Second statement should be error
    assert_instance_of CppAst::Nodes::ErrorStatement, program.statements[1]
    
    # Third statement should be valid
    assert_instance_of CppAst::Nodes::VariableDeclaration, program.statements[2]
    
    # Should have recorded errors
    assert_equal 1, parser.errors.size
  end
  
  def test_roundtrip_with_error
    source = <<~CPP
      int x = 5;
      virtual void foo();
      int y = 10;
    CPP
    
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ProgramParser.new(lexer)
    program = parser.parse
    
    # Roundtrip should preserve source including error
    result = program.to_source
    assert_equal source, result
  end
  
  def test_multiple_errors
    source = <<~CPP
      int x = 5;
      virtual void foo();
      int y = 10;
      inline void bar();
      int z = 15;
    CPP
    
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ProgramParser.new(lexer)
    program = parser.parse
    
    # Should have 5 statements
    assert_equal 5, program.statements.size
    
    # Should have 2 error statements
    errors = program.statements.select { |s| s.is_a?(CppAst::Nodes::ErrorStatement) }
    assert_equal 2, errors.size
    
    # Should have recorded both errors
    assert_equal 2, parser.errors.size
  end
end

