# frozen_string_literal: true

require_relative "../test_helper"

class PreprocessorTest < Minitest::Test
  include CppAst::Builder::DSL
  
  def test_define_directive_simple
    directive = define_directive("DEBUG")
    assert_equal "#define DEBUG", directive.to_source
  end
  
  def test_define_directive_with_value
    directive = define_directive("VERSION", "1.0")
    assert_equal "#define VERSION 1.0", directive.to_source
  end
  
  def test_ifdef_directive
    directive = ifdef_directive("DEBUG", 
      var_decl("int", "debug_level"),
      inline_comment("Debug mode enabled")
    )
    
    expected = <<~CPP.strip
      #ifdef DEBUG
      int debug_level;
      // Debug mode enabled
      #endif
    CPP
    
    assert_equal expected, directive.to_source
  end
  
  def test_ifndef_directive
    directive = ifndef_directive("NDEBUG",
      var_decl("bool", "debug_enabled"),
      inline_comment("Debug mode disabled")
    )
    
    expected = <<~CPP.strip
      #ifndef NDEBUG
      bool debug_enabled;
      // Debug mode disabled
      #endif
    CPP
    
    assert_equal expected, directive.to_source
  end
  
  def test_preprocessor_with_leading_trivia
    directive = define_directive("API_VERSION", "2.0")
    directive = directive.with_leading("  ")
    assert_equal "  #define API_VERSION 2.0", directive.to_source
  end
  
  def test_complex_preprocessor_example
    program = program(
      define_directive("GL_VERSION_MAJOR", "3"),
      define_directive("GL_VERSION_MINOR", "3"),
      ifdef_directive("DEBUG",
        define_directive("GL_CHECK_ERRORS"),
        inline_comment("Enable OpenGL error checking")
      ),
      ifndef_directive("NDEBUG",
        var_decl("bool", "debug_mode"),
        inline_comment("Debug mode is enabled")
      )
    )
    
    expected = <<~CPP.strip + "\n"
      #define GL_VERSION_MAJOR 3
      #define GL_VERSION_MINOR 3
      #ifdef DEBUG
      #define GL_CHECK_ERRORS
      // Enable OpenGL error checking
      #endif
      #ifndef NDEBUG
      bool debug_mode;
      // Debug mode is enabled
      #endif
    CPP
    
    assert_equal expected, program.to_source
  end
end
