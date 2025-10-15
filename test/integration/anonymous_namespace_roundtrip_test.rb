# frozen_string_literal: true

require_relative "../test_helper"

class AnonymousNamespaceRoundtripTest < Minitest::Test
  def test_anonymous_namespace_empty
    source = <<~CPP
      namespace {
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_anonymous_namespace_with_function
    source = <<~CPP
      namespace {
          void helper() {
          }
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_anonymous_namespace_with_variable
    source = <<~CPP
      namespace {
          int internal_counter;
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_named_and_anonymous_namespaces
    source = <<~CPP
      namespace MyNamespace {
          int x;
      }
      
      namespace {
          int y;
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
  
  def test_anonymous_namespace_with_spaces
    source = <<~CPP
      namespace {
          int x;
      }
    CPP
    
    program = CppAst.parse(source)
    assert_equal source, program.to_source
  end
end

