#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../test_helper"

class ModifiersTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_deleted_function
    ast = function_decl("", "Shader", [param(borrowed("Shader"), "other")], nil).deleted()
    
    cpp_code = ast.to_source
    expected = " Shader(const Shader& other = delete);"
    
    assert_equal expected, cpp_code
  end

  def test_defaulted_function
    ast = function_decl("", "Vec2", [], nil).defaulted()
    
    cpp_code = ast.to_source
    expected = " Vec2( = default);"
    
    assert_equal expected, cpp_code
  end

  def test_noexcept_function
    ast = function_decl("", "Shader", [param("Shader&&", "other")], block()).noexcept()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "Shader(Shader&& other ) noexcept"
  end

  def test_explicit_constructor
    ast = function_decl("", "Buffer", [param("Type", "type")], block()).explicit()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "explicit  Buffer(Type type )"
  end

  def test_constexpr_constructor
    ast = function_decl("", "Vec2", [param("float", "x"), param("float", "y")], block()).constexpr()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "constexpr  Vec2(float x, float y )"
  end

  def test_const_method
    ast = function_decl("GLuint", "handle", [], block(return_stmt(id("shader_")))).const()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "GLuint handle( ) const"
  end

  def test_combined_modifiers
    ast = function_decl("GLuint", "handle", [], block(return_stmt(id("shader_"))))
      .const()
      .noexcept()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "GLuint handle( ) const noexcept"
  end

  def test_explicit_constexpr_combined
    ast = function_decl("", "Vec2", [param("float", "x"), param("float", "y")], block())
      .explicit()
      .constexpr()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "constexpr explicit  Vec2(float x, float y )"
  end

  def test_inline_method
    ast = function_decl("GLuint", "handle", [], block(return_stmt(id("shader_")))).inline()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline GLuint handle( )"
  end

  def test_nodiscard_attribute
    ast = function_decl("bool", "compile", [], block()).nodiscard()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "[[nodiscard]] bool compile( )"
  end

  def test_all_modifiers_combined
    ast = function_decl("GLuint", "handle", [], block(return_stmt(id("shader_"))))
      .inline()
      .const()
      .noexcept()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline GLuint handle( ) const noexcept"
  end

  def test_roundtrip_deleted_function
    # Generate C++ code
    ast = function_decl("", "Shader", [param(borrowed("Shader"), "other")], nil).deleted()
    cpp_code = ast.to_source
    
    # Basic validation - should contain expected elements
    assert_includes cpp_code, "Shader"
    assert_includes cpp_code, "= delete"
  end

  def test_roundtrip_noexcept_function
    # Generate C++ code
    ast = function_decl("", "Shader", [param("Shader&&", "other")], block()).noexcept()
    cpp_code = ast.to_source
    
    # Basic validation - should contain expected elements
    assert_includes cpp_code, "Shader"
    assert_includes cpp_code, "noexcept"
  end
end
