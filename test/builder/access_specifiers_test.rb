# frozen_string_literal: true

require "test_helper"

class AccessSpecifiersTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_public_section
    ast = public_section(
      function_decl("void", "public_method", [], block()),
      field_def("int", "public_field")
    )
    
    cpp_code = ast.map(&:to_source).join("\n")
    assert_includes cpp_code, "public:"
    assert_includes cpp_code, "void public_method"
    assert_includes cpp_code, "int public_field;"
  end

  def test_private_section
    ast = private_section(
      field_def("int", "private_field"),
      function_decl("void", "private_method", [], block())
    )
    
    cpp_code = ast.map(&:to_source).join("\n")
    assert_includes cpp_code, "private:"
    assert_includes cpp_code, "int private_field;"
    assert_includes cpp_code, "void private_method"
  end

  def test_protected_section
    ast = protected_section(
      field_def("int", "protected_field"),
      function_decl("void", "protected_method", [], block())
    )
    
    cpp_code = ast.map(&:to_source).join("\n")
    assert_includes cpp_code, "protected:"
    assert_includes cpp_code, "int protected_field;"
    assert_includes cpp_code, "void protected_method"
  end

  def test_class_with_access_specifiers
    public_members = public_section(
      function_decl("", "TestClass", [], block())
        .defaulted(),
      function_decl("void", "public_method", [], block())
    )
    
    private_members = private_section(
      field_def("int", "private_field", default: "0"),
      function_decl("void", "private_method", [], block())
    )
    
    ast = class_decl("TestClass", *public_members, *private_members)
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "class TestClass"
    assert_includes cpp_code, "public:"
    assert_includes cpp_code, "TestClass() = default;"
    assert_includes cpp_code, "void public_method"
    assert_includes cpp_code, "private:"
    assert_includes cpp_code, "int private_field{0};"
    assert_includes cpp_code, "void private_method"
  end

  def test_raii_class_with_access_specifiers
    public_members = public_section(
      function_decl("", "RAIIClass", [], block())
        .defaulted(),
      function_decl("", "~RAIIClass", [], block()),
      function_decl("", "RAIIClass", [param("const RAIIClass&", "other")], block())
        .deleted(),
      function_decl("RAIIClass&", "operator=", [param("const RAIIClass&", "other")], block())
        .deleted(),
      function_decl("", "RAIIClass", [param("RAIIClass&&", "other")], block())
        .noexcept(),
      function_decl("RAIIClass&", "operator=", [param("RAIIClass&&", "other")], block())
        .noexcept(),
      function_decl("bool", "is_valid", [], block())
        .inline_body(block(return_stmt(binary("!=", id("handle_"), int(0)))))
        .const()
        .noexcept()
    )
    
    private_members = private_section(
      field_def("int", "handle_", default: "0")
    )
    
    ast = class_decl("RAIIClass", *public_members, *private_members)
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "class RAIIClass"
    assert_includes cpp_code, "public:"
    assert_includes cpp_code, "RAIIClass() = default;"
    assert_includes cpp_code, "~RAIIClass"
    assert_includes cpp_code, "RAIIClass(const RAIIClass& other) = delete;"
    assert_includes cpp_code, "RAIIClass& operator=(const RAIIClass& other) = delete;"
    assert_includes cpp_code, "RAIIClass(RAIIClass&& other ) noexcept"
    assert_includes cpp_code, "RAIIClass& operator=(RAIIClass&& other ) noexcept"
    assert_includes cpp_code, "inline bool is_valid"
    assert_includes cpp_code, "private:"
    assert_includes cpp_code, "int handle_{0};"
  end
end
