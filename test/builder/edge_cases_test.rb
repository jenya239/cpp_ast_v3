# frozen_string_literal: true

require "test_helper"

class EdgeCasesTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_empty_template_parameters
    ast = template_class("EmptyTemplate", [], 
      function_decl("void", "method", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <>"
    assert_includes cpp_code, "class EmptyTemplate"
  end

  def test_nested_template_classes
    ast = template_class("Outer", ["typename T"],
      template_class("Inner", ["typename U"],
        function_decl("void", "method", [param("T", "t"), param("U", "u")], block())
      )
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <typename T>"
    assert_includes cpp_code, "template <typename U>"
    assert_includes cpp_code, "void method(T t, U u)"
  end

  def test_multiple_modifiers_combination
    ast = function_decl("void", "complex_method", [param("const std::string&", "data")], block())
      .inline()
      .const()
      .noexcept()
      .nodiscard()
      .static()
    cpp_code = ast.to_source
    assert_includes cpp_code, "static inline [[nodiscard]] void complex_method(const std::string& data) const noexcept"
  end

  def test_template_method_with_complex_parameters
    ast = template_method("void", "process", ["typename T", "typename U"], 
      [param("std::span<const T>", "data"), param("std::function<U(T)>", "transform")],
      block())
      .const()
      .noexcept()
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <typename T, typename U>"
    assert_includes cpp_code, "void process(std::span<const T> data, std::function<U(T)> transform) const noexcept"
  end

  def test_enum_class_with_mixed_values
    ast = enum_class("MixedEnum", [
      ["FIRST"],
      ["SECOND", "10"],
      ["THIRD"],
      ["FOURTH", "100"]
    ], underlying_type: "int")
    cpp_code = ast.to_source
    assert_includes cpp_code, "enum class MixedEnum : int{FIRST, SECOND = 10, THIRD, FOURTH = 100};"
  end

  def test_constructor_with_complex_initializer_list
    ast = function_decl("", "ComplexClass", 
      [param("int", "value"), param("const std::string&", "name"), param("float", "factor")], 
      block())
      .with_initializer_list("member_(value), name_(name), factor_(factor), computed_(value * factor)")
      .explicit()
      .constexpr()
    cpp_code = ast.to_source
    assert_includes cpp_code, "constexpr explicit ComplexClass(int value, const std::string& name, float factor) : member_(value), name_(name), factor_(factor), computed_(value * factor)"
  end

  def test_friend_with_template_specialization
    ast = class_decl("MyClass",
      friend_decl("struct", "std::hash<MyClass>"),
      friend_decl("class", "std::equal_to<MyClass>"),
      function_decl("void", "method", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "friend struct std::hash<MyClass>;"
    assert_includes cpp_code, "friend class std::equal_to<MyClass>;"
  end

  def test_using_aliases_with_complex_types
    ast = namespace_decl("MyNamespace",
      using_alias("StringVector", "std::vector<std::string>"),
      using_alias("FunctionPtr", "std::function<void(int)>"),
      using_alias("TemplateType", "std::map<std::string, int>"),
      function_decl("void", "test", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "using StringVector = std::vector<std::string>;"
    assert_includes cpp_code, "using FunctionPtr = std::function<void(int)>;"
    assert_includes cpp_code, "using TemplateType = std::map<std::string, int>;"
  end

  def test_inline_method_with_complex_body
    ast = function_decl("std::optional<int>", "find_value", [param("const std::vector<int>&", "vec"), param("int", "target")], block())
      .inline_body(block(
        if_stmt(
          binary_expr(id("vec"), "==", id("vec")),
          block(return_stmt(id("std::nullopt"))),
          block(return_stmt(id("target")))
        )
      ))
      .const()
      .nodiscard()
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline [[nodiscard]] std::optional<int> find_value(const std::vector<int>& vec, int target) const"
  end

  def test_template_specialization_with_complex_type
    ast = namespace_decl("std",
      template_class("hash", ["typename T"],
        function_decl("size_t", "operator()", [param("const T&", "k")], block())
          .const()
          .noexcept()
      ).specialized()
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "namespace std"
    assert_includes cpp_code, "template <>"
    assert_includes cpp_code, "size_t operator()(const T& k) const noexcept"
  end

  def test_class_with_all_edge_cases
    ast = class_decl("EdgeCaseClass",
      using_alias("Index", "int"),
      friend_decl("struct", "std::hash<EdgeCaseClass>"),
      enum_class("State", [["INIT"], ["READY", "1"], ["ERROR", "2"]]),
      template_method("void", "process", ["typename T"], 
        [param("std::span<const T>", "data")],
        block()),
      function_decl("", "EdgeCaseClass", [param("Index", "index")], block())
        .with_initializer_list("index_(index), computed_(index * 2)")
        .explicit(),
      function_decl("Index", "get_index", [], block())
        .inline_body(block(return_stmt(id("index_"))))
        .const(),
      function_decl("", "EdgeCaseClass", [param("const EdgeCaseClass&", "other")], block())
        .deleted(),
      function_decl("EdgeCaseClass&", "operator=", [param("const EdgeCaseClass&", "other")], block())
        .deleted(),
      function_decl("", "EdgeCaseClass", [param("EdgeCaseClass&&", "other")], block())
        .noexcept(),
      function_decl("EdgeCaseClass&", "operator=", [param("EdgeCaseClass&&", "other")], block())
        .noexcept()
    )
    cpp_code = ast.to_source
    
    # Check all edge cases are present
    assert_includes cpp_code, "using Index = int;"
    assert_includes cpp_code, "friend struct std::hash<EdgeCaseClass>;"
    assert_includes cpp_code, "enum class State{INIT, READY = 1, ERROR = 2};"
    assert_includes cpp_code, "template <typename T>"
    assert_includes cpp_code, "explicit EdgeCaseClass(Index index) : index_(index), computed_(index * 2)"
    assert_includes cpp_code, "inline Index get_index() const"
    assert_includes cpp_code, "EdgeCaseClass(const EdgeCaseClass& other) = delete"
    assert_includes cpp_code, "EdgeCaseClass(EdgeCaseClass&& other) noexcept"
  end

  def test_empty_class
    ast = class_decl("EmptyClass")
    cpp_code = ast.to_source
    assert_includes cpp_code, "class EmptyClass{}"
  end

  def test_class_with_only_using_aliases
    ast = class_decl("AliasClass",
      using_alias("Type1", "int"),
      using_alias("Type2", "float"),
      using_alias("Type3", "std::string")
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "using Type1 = int;"
    assert_includes cpp_code, "using Type2 = float;"
    assert_includes cpp_code, "using Type3 = std::string;"
  end

  def test_class_with_only_friend_declarations
    ast = class_decl("FriendClass",
      friend_decl("class", "Friend1"),
      friend_decl("struct", "Friend2"),
      friend_decl("", "Friend3")
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "friend class Friend1;"
    assert_includes cpp_code, "friend struct Friend2;"
    assert_includes cpp_code, "friend  Friend3;"
  end

  def test_class_with_only_enum_class
    ast = class_decl("EnumClass",
      enum_class("Status", [["OK"], ["ERROR", "1"]]),
      enum_class("Mode", [["AUTO"], ["MANUAL", "2"]], underlying_type: "uint8_t")
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "enum class Status{OK, ERROR = 1};"
    assert_includes cpp_code, "enum class Mode : uint8_t{AUTO, MANUAL = 2};"
  end

  def test_namespace_with_mixed_content
    ast = namespace_decl("MixedNamespace",
      using_alias("Type", "int"),
      friend_decl("struct", "std::hash<MixedNamespace>"),
      enum_class("Value", [["A"], ["B", "1"]]),
      function_decl("void", "method", [], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "namespace MixedNamespace"
    assert_includes cpp_code, "using Type = int;"
    assert_includes cpp_code, "friend struct std::hash<MixedNamespace>;"
    assert_includes cpp_code, "enum class Value{A, B = 1};"
    assert_includes cpp_code, "void method()"
  end
end
