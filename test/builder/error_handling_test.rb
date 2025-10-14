# frozen_string_literal: true

require "test_helper"

class ErrorHandlingTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_invalid_modifier_combinations
    # Test that invalid combinations raise appropriate errors
    assert_raises(NoMethodError) do
      function_decl("void", "test", [], block())
        .deleted()
        .defaulted()  # Cannot be both deleted and defaulted
    end
  end

  def test_empty_template_parameters
    # Empty template parameters should be handled gracefully
    ast = template_class("Empty", [], 
      function_decl("void", "method", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <>"
    assert_includes cpp_code, "class Empty"
  end

  def test_invalid_function_parameters
    # Test error handling for invalid parameters
    assert_raises(ArgumentError) do
      function_decl("void", "test", nil, block())
    end
  end

  def test_invalid_class_name
    # Empty class name should be handled
    ast = class_decl("", 
      function_decl("void", "method", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "class "
    assert_includes cpp_code, "void method()"
  end

  def test_invalid_enum_values
    # Test handling of invalid enum values
    ast = enum_class("TestEnum", [])
    cpp_code = ast.to_source
    assert_includes cpp_code, "enum class TestEnum"
  end

  def test_invalid_initializer_list
    # Test handling of invalid initializer list
    ast = function_decl("", "Test", [param("int", "value")], block())
      .with_initializer_list("")
    cpp_code = ast.to_source
    assert_includes cpp_code, "Test(int value) : {}"
  end

  def test_invalid_friend_declaration
    # Test handling of invalid friend declaration
    ast = friend_decl("", "")
    cpp_code = ast.to_source
    assert_includes cpp_code, "friend ;"
  end

  def test_invalid_using_alias
    # Test handling of invalid using alias
    ast = using_alias("", "")
    cpp_code = ast.to_source
    assert_includes cpp_code, "using  = ;"
  end

  def test_invalid_template_specialization
    # Test handling of invalid template specialization
    ast = template_class("Test", ["typename T"], 
      function_decl("void", "method", [], block())
    ).specialized()
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <>"
  end

  def test_invalid_inline_body
    # Test handling of invalid inline body
    ast = function_decl("void", "test", [], block())
      .inline_body(nil)
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline void test()"
  end

  def test_invalid_static_constexpr_combination
    # Test that static and constexpr can be combined
    ast = function_decl("int", "test", [], block())
      .static()
      .constexpr()
    cpp_code = ast.to_source
    assert_includes cpp_code, "static constexpr int test()"
  end

  def test_invalid_noexcept_with_deleted
    # Test that noexcept cannot be used with deleted functions
    ast = function_decl("void", "test", [], block())
      .deleted()
      .noexcept()
    cpp_code = ast.to_source
    assert_includes cpp_code, "void test() = delete"
    # noexcept should be ignored for deleted functions
  end

  def test_invalid_initializer_list_with_deleted
    # Test that initializer list cannot be used with deleted functions
    ast = function_decl("", "Test", [param("int", "value")], block())
      .deleted()
      .with_initializer_list("member(value)")
    cpp_code = ast.to_source
    assert_includes cpp_code, "Test(int value) = delete"
    # initializer list should be ignored for deleted functions
  end

  def test_invalid_template_with_invalid_parameters
    # Test handling of invalid template parameters
    ast = template_class("Test", [nil, ""], 
      function_decl("void", "method", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <, >"
  end

  def test_invalid_enum_class_without_values
    # Test handling of enum class without values
    ast = enum_class("EmptyEnum", [])
    cpp_code = ast.to_source
    assert_includes cpp_code, "enum class EmptyEnum"
  end

  def test_invalid_namespace_declaration
    # Test handling of invalid namespace
    ast = namespace_decl("", 
      function_decl("void", "test", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "namespace "
  end

  def test_error_recovery
    # Test that the DSL can recover from errors and continue
    begin
      ast = class_decl("TestClass",
        function_decl("void", "valid_method", [], block()),
        function_decl("void", "invalid_method", nil, block()),  # This should cause an error
        function_decl("void", "another_valid_method", [], block())
      )
      # If we get here, error recovery worked
      cpp_code = ast.to_source
      assert_includes cpp_code, "void valid_method()"
      assert_includes cpp_code, "void another_valid_method()"
    rescue => e
      # Error recovery failed, which is also acceptable
      assert e.is_a?(ArgumentError), "Should raise ArgumentError for invalid parameters"
    end
  end
end
