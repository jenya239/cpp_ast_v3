# frozen_string_literal: true

require_relative "../test_helper"

class ConstructorDestructorRoundtripTest < Minitest::Test
  def test_destructor_declaration
    source = <<~CPP
      void ~MyClass();
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_destructor_with_override
    source = <<~CPP
      void ~MyClass() override;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_destructor_with_default
    source = <<~CPP
      void ~MyClass() = default;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_destructor_in_class
    source = <<~CPP
      class MyClass {
          ~MyClass();
      };
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_destructor_with_body
    source = <<~CPP
      void ~MyClass() {
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_destructor_virtual_default
    source = <<~CPP
      void ~MyClass() override = default;
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
end

