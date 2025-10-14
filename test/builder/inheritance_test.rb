#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../test_helper"

class InheritanceTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_single_inheritance
    ast = class_with_inheritance("Derived", ["public Base"], 
      function_decl("void", "method", [], block())
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "class Derived  : public Base"
  end
  
  def test_multiple_inheritance
    ast = class_with_inheritance("Derived", ["public Base1", "protected Base2"], 
      function_decl("void", "method", [], block())
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "class Derived  : public Base1, protected Base2"
  end
  
  def test_virtual_inheritance
    ast = class_with_inheritance("Derived", ["public virtual Base"], 
      function_decl("void", "method", [], block())
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "class Derived  : public virtual Base"
  end
  
  def test_no_inheritance
    ast = class_with_inheritance("Standalone", [], 
      function_decl("void", "method", [], block())
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "class Standalone"
    refute_includes cpp_code, ":"
  end
  
  def test_inheritance_with_virtual_methods
    ast = class_with_inheritance("AbstractBase", [], 
      function_decl("void", "pure_virtual_method", [], nil).pure_virtual(),
      function_decl("", "~AbstractBase", [], block()).virtual()
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "class AbstractBase"
    assert_includes cpp_code, "virtual void pure_virtual_method() = 0"
    assert_includes cpp_code, "virtual ~AbstractBase()"
  end
  
  def test_derived_with_override
    ast = class_with_inheritance("ConcreteDerived", ["public AbstractBase"], 
      function_decl("void", "pure_virtual_method", [], block()).override(),
      function_decl("", "~ConcreteDerived", [], block()).override()
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "class ConcreteDerived  : public AbstractBase"
    assert_includes cpp_code, "void pure_virtual_method()  override"
    assert_includes cpp_code, "~ConcreteDerived()  override"
  end
end
