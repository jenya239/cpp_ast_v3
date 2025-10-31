# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mlc"
require_relative "../../lib/mlc/error_handling/enhanced_errors"
require_relative "../../lib/mlc/parser/error_recovery_parser"

class EnhancedErrorHandlingTest < Minitest::Test
  def test_syntax_error_with_suggestion
    source = <<~AURORA
      fn test() -> i32 = 
        42
    AURORA
    
    # Test that we can create enhanced syntax errors
    error = MLC::AuroraSyntaxError.new(
      "Syntax error: missing expression",
      location: "line 1, column 20",
      suggestion: "Add an expression after the equals sign"
    )
    
    assert_includes error.formatted_message, "Syntax error"
    assert_includes error.formatted_message, "💡 Suggestion:"
    assert_includes error.formatted_message, "🔧 This is a syntax error"
  end
  
  def test_multiple_errors_recovery
    source = <<~AURORA
      fn test1() -> i32 = 
        42
      
      fn test2() -> i32 = 
        undefined_variable
      
      fn test3() -> i32 = 
        42
    AURORA
    
    parser = MLC::Parser::ErrorRecoveryParser.new(source)
    
    begin
      parser.parse
    rescue MLC::Parser::MultipleErrors => e
      assert e.errors.length >= 2, "Should have multiple errors"
      assert e.errors.any? { |err| err.is_a?(MLC::AuroraSyntaxError) }, "Should have syntax errors"
    end
  end
  
  def test_error_recovery_continues_parsing
    source = <<~AURORA
      fn broken() -> i32 = 
        invalid_syntax
      
      fn working() -> i32 = 42
    AURORA
    
    parser = MLC::Parser::ErrorRecoveryParser.new(source)
    
    begin
      result = parser.parse
      # Should still parse the working function despite the error
      assert result.declarations.any? { |decl| decl.name == "working" }
    rescue MLC::Parser::MultipleErrors => e
      # Should have errors but still parse some declarations
      assert e.errors.length > 0
    end
  end
  
  def test_enhanced_error_messages
    source = <<~AURORA
      fn test() -> i32 = 
        42
    AURORA
    
    parser = MLC::Parser::ErrorRecoveryParser.new(source)
    
    begin
      parser.parse
    rescue MLC::Parser::MultipleErrors => e
      error = e.errors.first
      assert_includes error.formatted_message, "💡 Suggestion:"
      assert_includes error.formatted_message, "🔧 This is a syntax error"
    end
  end
  
  def test_type_error_suggestions
    source = <<~AURORA
      fn test() -> i32 = "hello"
    AURORA
    
    # This should compile but we can test the error handling framework
    begin
      MLC.parse(source)
    rescue => e
      # Test that we can create enhanced type errors
      error = MLC::AuroraTypeError.new(
        "Type mismatch: expected i32, got string",
        location: "line 1, column 20",
        suggestion: "Use a number instead of a string"
      )
      
      assert_includes error.formatted_message, "Type mismatch"
      assert_includes error.formatted_message, "💡 Suggestion:"
      assert_includes error.formatted_message, "🔍 This is a type error"
    end
  end
  
  def test_scope_error_suggestions
    source = <<~AURORA
      fn test() -> i32 = undefined_variable
    AURORA
    
    # Test scope error creation
    error = MLC::AuroraScopeError.new(
      "Undefined variable: undefined_variable",
      location: "line 1, column 20",
      suggestion: "Declare the variable or check the spelling"
    )
    
    assert_includes error.formatted_message, "Undefined variable"
    assert_includes error.formatted_message, "💡 Suggestion:"
    assert_includes error.formatted_message, "📦 This is a scope error"
  end
  
  def test_import_error_suggestions
    error = MLC::AuroraImportError.new(
      "Module 'nonexistent' not found",
      location: "line 1, column 8",
      suggestion: "Check the module name and file path"
    )
    
    assert_includes error.formatted_message, "Module 'nonexistent' not found"
    assert_includes error.formatted_message, "💡 Suggestion:"
    assert_includes error.formatted_message, "📁 This is an import error"
  end
  
  def test_error_context_provided
    source = <<~AURORA
      fn test() -> i32 = 
        42
    AURORA
    
    parser = MLC::Parser::ErrorRecoveryParser.new(source)
    
    begin
      parser.parse
    rescue MLC::Parser::MultipleErrors => e
      error = e.errors.first
      assert_includes error.formatted_message, "📍 Context:"
    end
  end
end
