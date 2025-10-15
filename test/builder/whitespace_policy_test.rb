# frozen_string_literal: true

require "test_helper"

class WhitespacePolicyTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_enum_without_spaces
    ast = enum_class("State", [
      ["INIT"],
      ["READY", "1"],
      ["ERROR", "2"]
    ])
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "enum class State{INIT, READY = 1, ERROR = 2};"
    refute_includes cpp_code, "enum class State {"  # без пробела перед {
  end

  def test_enum_with_underlying_type
    ast = enum_class("Format", [
      ["A8"],
      ["RGB8"]
    ], underlying_type: "uint8_t")
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "enum class Format : uint8_t{A8, RGB8};"
  end

  def test_function_with_proper_spacing
    ast = function_decl("void", "test", [], block())
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "void test() {"
    refute_includes cpp_code, "void test(){"  # должен быть пробел перед {
  end

  def test_modifier_order
    ast = function_decl("void", "test", [], block())
      .static()
      .inline()
      .constexpr()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "constexpr static inline void test()"
  end

  def test_pure_virtual_method
    ast = function_decl("void", "pure_virtual", [], nil)
      .pure_virtual()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "virtual void pure_virtual() = 0"
    refute_includes cpp_code, "virtual void pure_virtual( = 0"  # должно быть () = 0
  end

  def test_template_spacing
    ast = template_class("Empty", [])
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <>"
    refute_includes cpp_code, "template  <>"  # без двойного пробела
  end

  def test_friend_declaration
    ast = friend_decl("class", "Friend1")
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "friend class Friend1;"
    refute_includes cpp_code, "friend  class Friend1;"  # без двойного пробела
  end

  def test_parameter_spacing
    ast = function_decl("void", "test", [
      param("int", "x"),
      param("float", "y")
    ], block())
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "void test(int x, float y) {"
    refute_includes cpp_code, "void test(int x , float y )"  # без пробелов перед )
  end

  def test_inline_method_spacing
    ast = function_decl("int", "get_value", [], block())
      .inline_body(block(return_stmt(id("value"))))
      .const()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline int get_value() const {"
    refute_includes cpp_code, "inline int get_value() const{"  # должен быть пробел перед {
  end

  def test_override_spacing
    ast = function_decl("void", "method", [], block())
      .override()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "void method() override {"
    refute_includes cpp_code, "void method() override{"  # должен быть пробел перед {
  end

  def test_attributes_order
    ast = function_decl("void", "test", [], block())
      .nodiscard()
      .maybe_unused()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "[[maybe_unused]] [[nodiscard]] void test()"
  end
end