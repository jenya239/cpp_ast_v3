# frozen_string_literal: true

require_relative "../test_helper"

class EnumRoundtripTest < Minitest::Test
  def test_simple_enum
    source = <<~CPP
      enum Color {
          Red,
          Green,
          Blue
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_enum_class
    source = <<~CPP
      enum class Status {
          Ok,
          Error
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_enum_with_values
    source = <<~CPP
      enum Level {
          Low = 0,
          Medium = 5,
          High = 10
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_anonymous_enum
    source = <<~CPP
      enum {
          CONSTANT1,
          CONSTANT2
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_enum_single_line
    source = "enum Color { Red, Green, Blue };\n"
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_enum_with_trailing_comma
    source = <<~CPP
      enum Color {
          Red,
          Green,
          Blue,
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_enum_class_with_type
    source = <<~CPP
      enum class Color : int {
          Red,
          Green
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_enum_in_namespace
    source = <<~CPP
      namespace MyNamespace {
          enum Status {
              Ok,
              Error
          };
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
end

