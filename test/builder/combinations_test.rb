# frozen_string_literal: true

require "test_helper"

class CombinationsTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_template_with_all_modifiers
    ast = template_method("void", "data", ["typename T"], 
      [param("std::span<const T>", "data"), param("Usage", "usage", default: "Usage::Static")],
      block())
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <typename T>"
    assert_includes cpp_code, "void data"
  end

  def test_enum_class_with_underlying_type_in_namespace
    ast = namespace_decl("gtkgl::text",
      enum_class("AtlasFormat", [
        ["A8"],
        ["RGB8"], 
        ["RGBA8"]
      ], underlying_type: "uint8_t")
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "namespace gtkgl::text"
    assert_includes cpp_code, "enum class AtlasFormat : uint8_t{A8, RGB8, RGBA8};"
  end

  def test_inline_method_with_const_noexcept_in_class
    ast = class_decl("Shader",
      function_decl("GLuint", "handle", [], block())
        .inline_body(block(return_stmt(id("shader_"))))
        .const()
        .noexcept(),
      function_decl("bool", "is_valid", [], block())
        .inline_body(block(return_stmt(binary("!=", id("shader_"), int(0)))))
        .const()
        .noexcept()
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "class Shader"
    assert_includes cpp_code, "inline GLuint handle"
    assert_includes cpp_code, "const noexcept"
  end

  def test_static_constexpr_with_inline
    ast = class_decl("Color",
      function_decl("Color", "white", [], block())
        .inline_body(block(return_stmt(binary("=", id("r"), float(1.0)))))
        .static()
        .constexpr(),
      function_decl("Color", "black", [], block())
        .inline_body(block(return_stmt(binary("=", id("r"), float(0.0)))))
        .static()
        .constexpr()
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "static constexpr inline Color white"
    assert_includes cpp_code, "static constexpr inline Color black"
  end

  def test_template_class_with_enum_and_friend
    ast = template_class("Buffer", ["typename T"],
      enum_class("Type", [
        ["Array", "GL_ARRAY_BUFFER"],
        ["ElementArray", "GL_ELEMENT_ARRAY_BUFFER"]
      ]),
      friend_decl("struct", "std::hash<Buffer<T>>"),
      function_decl("void", "data", [param("std::span<const T>", "data")], block())
        .template_method("void", "data", ["typename T"], [param("std::span<const T>", "data")], block())
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <typename T>"
    assert_includes cpp_code, "enum class Type{Array = GL_ARRAY_BUFFER, ElementArray = GL_ELEMENT_ARRAY_BUFFER};"
    assert_includes cpp_code, "friend struct std::hash<Buffer<T>>;"
  end

  def test_constructor_with_initializer_list_and_modifiers
    ast = class_decl("Vec2",
      function_decl("", "Vec2", [param("float", "x_"), param("float", "y_")], block())
        .with_initializer_list("x(x_), y(y_)")
        .explicit()
        .constexpr(),
      function_decl("", "Vec2", [], block())
        .with_initializer_list("x(0.0f), y(0.0f)")
        .defaulted()
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "constexpr explicit Vec2(float x_, float y_) : x(x_), y(y_){}"
    assert_includes cpp_code, "Vec2() = default"
  end

  def test_using_aliases_with_template_class
    ast = namespace_decl("gtkgl::text",
      using_alias("GlyphIndex", "uint32_t"),
      using_alias("FontFaceID", "uint32_t"),
      template_class("GlyphCache", ["typename T"],
        function_decl("void", "insert", [param("GlyphIndex", "index"), param("T", "value")], block())
      )
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "using GlyphIndex = uint32_t;"
    assert_includes cpp_code, "using FontFaceID = uint32_t;"
    assert_includes cpp_code, "template <typename T>"
  end

  def test_deleted_copy_with_move_semantics
    ast = class_decl("Shader",
      function_decl("", "Shader", [param("const Shader&", "other")], block())
        .deleted(),
      function_decl("Shader&", "operator=", [param("const Shader&", "other")], block())
        .deleted(),
      function_decl("", "Shader", [param("Shader&&", "other")], block())
        .noexcept(),
      function_decl("Shader&", "operator=", [param("Shader&&", "other")], block())
        .noexcept()
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "Shader(const Shader&) = delete"
    assert_includes cpp_code, "Shader& operator=(const Shader&) = delete"
    assert_includes cpp_code, "Shader(Shader&& other) noexcept"
    assert_includes cpp_code, "Shader& operator=(Shader&& other) noexcept"
  end

  def test_nodiscard_with_constexpr
    ast = function_decl("std::optional<std::string>", "compile_error", [], block())
      .nodiscard()
      .const()
    cpp_code = ast.to_source
    assert_includes cpp_code, "[[nodiscard]] std::optional<std::string> compile_error() const"
  end

  def test_template_specialization_in_namespace
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

  def test_multiple_modifiers_combination
    ast = function_decl("void", "process", [param("const std::string&", "data")], block())
      .inline()
      .const()
      .noexcept()
      .nodiscard()
    cpp_code = ast.to_source
    assert_includes cpp_code, "inline [[nodiscard]] void process(const std::string& data) const noexcept"
  end

  def test_enum_class_with_values_and_underlying_type
    ast = enum_class("RenderMode", [
      ["BITMAP", "0"],
      ["MSDF", "1"], 
      ["SDF", "2"]
    ], underlying_type: "uint8_t")
    cpp_code = ast.to_source
    expected = "enum class RenderMode : uint8_t{BITMAP = 0, MSDF = 1, SDF = 2};"
    assert_equal expected, cpp_code
  end

  def test_template_method_with_span_and_default_params
    ast = template_method("void", "set_uniform", ["typename T"], 
      [param("const std::string&", "name"), param("std::span<const T>", "values")],
      block())
      .const()
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <typename T>"
    assert_includes cpp_code, "void set_uniform(const std::string& name, std::span<const T> values) const"
  end

  def test_class_with_all_features
    ast = class_decl("MyClass",
      using_alias("Index", "int"),
      friend_decl("struct", "hash<MyClass>"),
      enum_class("State", [["INIT", "0"], ["READY", "1"], ["ERROR", "2"]]),
      function_decl("", "MyClass", [param("Index", "index")], block())
        .with_initializer_list("index_(index)")
        .explicit(),
      function_decl("Index", "get_index", [], block())
        .inline_body(block(return_stmt(id("index_"))))
        .const(),
      function_decl("", "MyClass", [param("const MyClass&", "other")], block())
        .deleted()
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "using Index = int;"
    assert_includes cpp_code, "friend struct hash<MyClass>;"
    assert_includes cpp_code, "enum class State{INIT = 0, READY = 1, ERROR = 2};"
    assert_includes cpp_code, "explicit MyClass(Index index) : index_(index)"
    assert_includes cpp_code, "inline Index get_index() const{ return index_; }"
    assert_includes cpp_code, "MyClass(const MyClass&) = delete"
  end
end
