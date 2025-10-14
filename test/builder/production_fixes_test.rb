# frozen_string_literal: true

require "test_helper"

class ProductionFixesTest < Minitest::Test
  include CppAst::Builder::DSL

  def test_field_declaration_basic
    ast = field_def("float", "x")
    assert_equal "float x;", ast.to_source
  end

  def test_field_declaration_with_default
    ast = field_def("float", "x", default: "0.0f")
    assert_equal "float x{0.0f};", ast.to_source
  end

  def test_include_system
    ast = include_directive("cstdint")
    assert_equal "#include <cstdint>", ast.to_source
  end

  def test_include_local
    ast = include_directive("my_header.hpp", system: false)
    assert_equal "#include \"my_header.hpp\"", ast.to_source
  end

  def test_pragma_once
    ast = pragma_once()
    assert_equal "#pragma once", ast.to_source
  end

  def test_namespace_multiple_members
    ast = namespace_decl("gtkgl::text",
      using_alias("GlyphIndex", "uint32_t"),
      struct_decl("Vec2", 
        field_def("float", "x"),
        field_def("float", "y")
      )
    )
    cpp_code = ast.to_source
    assert_includes cpp_code, "namespace gtkgl::text"
    assert_includes cpp_code, "using GlyphIndex"
    assert_includes cpp_code, "struct Vec2"
  end

  def test_complete_header_file
    ast = program(
      pragma_once(),
      include_directive("cstdint"),
      include_directive("vector"),
      namespace_decl("gtkgl::text",
        using_alias("GlyphIndex", "uint32_t"),
        struct_decl("Vec2",
          field_def("float", "x", default: "0.0f"),
          field_def("float", "y", default: "0.0f"),
          function_decl("", "Vec2", [], block()).defaulted()
        )
      )
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "#pragma once"
    assert_includes cpp_code, "#include <cstdint>"
    assert_includes cpp_code, "namespace gtkgl::text"
    assert_includes cpp_code, "float x{0.0f};"
    assert_includes cpp_code, "Vec2() = default;"
  end

  def test_struct_with_field_declarations
    ast = struct_decl("Vec2",
      field_def("float", "x", default: "0.0f"),
      field_def("float", "y", default: "0.0f"),
      function_decl("", "Vec2", [], block()).defaulted(),
      function_decl("", "Vec2", [param("float", "x_"), param("float", "y_")], block())
        .with_initializer_list("x(x_), y(y_)")
        .constexpr()
    )
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "struct Vec2"
    assert_includes cpp_code, "float x{0.0f};"
    assert_includes cpp_code, "float y{0.0f};"
    assert_includes cpp_code, "Vec2() = default;"
    assert_includes cpp_code, "constexpr"
    assert_includes cpp_code, ": x(x_), y(y_)"
  end

  def test_enum_class_with_underlying_type
    ast = enum_class("AtlasFormat", [
      ["A8"],
      ["RGB8"],
      ["RGBA8"]
    ], underlying_type: "uint8_t")
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "enum class AtlasFormat : uint8_t"
    assert_includes cpp_code, "A8, RGB8, RGBA8"
  end

  def test_template_specialization
    ast = template_class("hash", ["typename T"],
      function_decl("size_t", "operator()", [param("const T&", "k")], block())
        .const()
        .noexcept()
    ).specialized()
    
    cpp_code = ast.to_source
    assert_includes cpp_code, "template <>"
    assert_includes cpp_code, "size_t operator()"
    assert_includes cpp_code, "const noexcept"
  end

  def test_complex_header_structure
    # Test realistic header file structure
    ast = program(
      pragma_once(),
      include_directive("cstdint"),
      include_directive("vector"),
      include_directive("optional"),
      namespace_decl("gtkgl::text",
        using_alias("GlyphIndex", "uint32_t"),
        using_alias("FontFaceID", "uint32_t"),
        
        struct_decl("Vec2",
          field_def("float", "x", default: "0.0f"),
          field_def("float", "y", default: "0.0f"),
          function_decl("", "Vec2", [], block()).defaulted(),
          function_decl("", "Vec2", [param("float", "x_"), param("float", "y_")], block())
            .with_initializer_list("x(x_), y(y_)")
            .constexpr(),
          function_decl("Vec2", "operator+", [param("const Vec2&", "other")], block())
            .inline_body(block(return_stmt(id("Vec2{x + other.x, y + other.y}"))))
            .const()
        ),
        
        enum_class("AtlasFormat", [
          ["A8"],
          ["RGB8"],
          ["RGBA8"]
        ], underlying_type: "uint8_t"),
        
        struct_decl("AtlasSlot",
          field_def("uint32_t", "page_id", default: "0"),
          field_def("uint32_t", "texture_id", default: "0"),
          function_decl("bool", "is_valid", [], block())
            .inline_body(block(return_stmt(binary("!=", id("texture_id"), int(0)))))
            .const()
        )
      ),
      
      namespace_decl("std",
        template_class("hash", ["typename T"],
          function_decl("size_t", "operator()", [param("const T&", "k")], block())
            .const()
            .noexcept()
        ).specialized()
      )
    )
    
    cpp_code = ast.to_source
    
    # Verify all components are present
    assert_includes cpp_code, "#pragma once"
    assert_includes cpp_code, "#include <cstdint>"
    assert_includes cpp_code, "#include <vector>"
    assert_includes cpp_code, "#include <optional>"
    assert_includes cpp_code, "namespace gtkgl::text"
    assert_includes cpp_code, "using GlyphIndex = uint32_t"
    assert_includes cpp_code, "using FontFaceID = uint32_t"
    assert_includes cpp_code, "struct Vec2"
    assert_includes cpp_code, "float x{0.0f};"
    assert_includes cpp_code, "float y{0.0f};"
    assert_includes cpp_code, "Vec2() = default;"
    assert_includes cpp_code, "constexpr"
    assert_includes cpp_code, ": x(x_), y(y_)"
    assert_includes cpp_code, "inline Vec2 operator+"
    assert_includes cpp_code, "enum class AtlasFormat : uint8_t"
    assert_includes cpp_code, "A8, RGB8, RGBA8"
    assert_includes cpp_code, "struct AtlasSlot"
    assert_includes cpp_code, "uint32_t page_id{0};"
    assert_includes cpp_code, "uint32_t texture_id{0};"
    assert_includes cpp_code, "inline bool is_valid"
    assert_includes cpp_code, "namespace std"
    assert_includes cpp_code, "template <>"
    assert_includes cpp_code, "size_t operator()"
    assert_includes cpp_code, "const noexcept"
  end
end
