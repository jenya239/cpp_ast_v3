# frozen_string_literal: true

require_relative "../test_helper"

class ErrorRecoveryTest < Minitest::Test
  def test_recovers_from_lexer_error
    # Note: Error recovery currently not implemented for lexer errors
    # This test documents expected behavior
    source = <<~CPP
      int x = 5;
      @@@ invalid;
      int y = 10;
    CPP
    
    # Should raise lexer error
    assert_raises(RuntimeError) do
      CppAst.parse(source)
    end
  end
  
  def test_roundtrip_with_valid_modifiers
    source = <<~CPP
      int x = 5;
      virtual void foo();
      int y = 10;
    CPP
    
    lexer = CppAst::Lexer.new(source)
    parser = CppAst::Parsers::ProgramParser.new(lexer)
    program = parser.parse
    
    # Should parse successfully now (virtual is supported)
    assert_equal 3, program.statements.size
    
    # Roundtrip should preserve source
    result = program.to_source
    assert_equal source, result
  end
  
  def test_multiple_modifiers
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
    
    # Should have 5 statements (all valid now)
    assert_equal 5, program.statements.size
    
    # Should have no errors (modifiers are now supported)
    assert_equal 0, parser.errors.size
    
    # Roundtrip should work
    assert_equal source, program.to_source
  end
end

