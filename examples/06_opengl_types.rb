#!/usr/bin/env ruby
# frozen_string_literal: true

# OpenGL Types Example - Aurora DSL
# Demonstrates generation of mathematical types and data structures using Aurora DSL

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== OpenGL Types Example ==="
puts "Generating mathematical types and data structures with Aurora DSL"
puts

# Generate types from text_types.hpp using Aurora DSL
ast = program(
  # Include directives
  expr_stmt(call(id("include"), string('"<cstdint>"'))),
  expr_stmt(call(id("include"), string('"<array>"'))),
  expr_stmt(call(id("include"), string('"<optional>"'))),
  expr_stmt(call(id("include"), string('"<string>"'))),
  expr_stmt(call(id("include"), string('"<vector>"'))),
  
  # Namespace declaration
  namespace_decl("gtkgl::text", [
    
    # Type aliases
    var_decl("using", "GlyphIndex = uint32_t"),
    var_decl("using", "FontFaceID = uint32_t"),
    var_decl("using", "AtlasPageID = uint32_t"),
    var_decl("using", "TextureID = uint32_t"),
    
    # Vec2 struct - Product type
    product_type("Vec2",
      field_def("x", "float"),
      field_def("y", "float")
    ),
    
    # Vec2 constructor
    function_decl("", "Vec2", [], block(
      # Default constructor
    )).with_suffix(" = default"),
    
    function_decl("", "Vec2", [
      param("float", "x_"),
      param("float", "y_")
    ], block(
      # Constructor with parameters
      expr_stmt(binary("=", id("x"), id("x_"))),
      expr_stmt(binary("=", id("y"), id("y_")))
    )).with_prefix_modifiers("constexpr "),
    
    # Vec2 operator+
    function_decl("Vec2", "operator+", [param(borrowed("Vec2"), "other")], block(
      return_stmt(
        # {x + other.x, y + other.y}
        binary("+", id("x"), member(id("other"), ".", "x")),
        binary("+", id("y"), member(id("other"), ".", "y"))
      )
    )).with_prefix_modifiers("const "),
    
    # Vec2 operator-
    function_decl("Vec2", "operator-", [param(borrowed("Vec2"), "other")], block(
      return_stmt(
        binary("-", id("x"), member(id("other"), ".", "x")),
        binary("-", id("y"), member(id("other"), ".", "y"))
      )
    )).with_prefix_modifiers("const "),
    
    # Vec2 operator*
    function_decl("Vec2", "operator*", [param("float", "s")], block(
      return_stmt(
        binary("*", id("x"), id("s")),
        binary("*", id("y"), id("s"))
      )
    )).with_prefix_modifiers("const "),
    
    # Vec2 operator+=
    function_decl("Vec2&", "operator+=", [param(borrowed("Vec2"), "other")], block(
      expr_stmt(binary("+=", id("x"), member(id("other"), ".", "x"))),
      expr_stmt(binary("+=", id("y"), member(id("other"), ".", "y"))),
      return_stmt(id("this"))
    )),
    
    # Rect struct - Product type
    product_type("Rect",
      field_def("x", "float"),
      field_def("y", "float"),
      field_def("width", "float"),
      field_def("height", "float")
    ),
    
    # Rect constructor
    function_decl("", "Rect", [], block(
      # Default constructor
    )).with_suffix(" = default"),
    
    function_decl("", "Rect", [
      param("float", "x_"),
      param("float", "y_"),
      param("float", "w_"),
      param("float", "h_")
    ], block(
      expr_stmt(binary("=", id("x"), id("x_"))),
      expr_stmt(binary("=", id("y"), id("y_"))),
      expr_stmt(binary("=", id("width"), id("w_"))),
      expr_stmt(binary("=", id("height"), id("h_")))
    )).with_prefix_modifiers("constexpr "),
    
    # Rect contains method
    function_decl("bool", "contains", [
      param("float", "px"),
      param("float", "py")
    ], block(
      return_stmt(
        binary("&&",
          binary(">=", id("px"), id("x")),
          binary("&&",
            binary("<", id("px"), binary("+", id("x"), id("width"))),
            binary("&&",
              binary(">=", id("py"), id("y")),
              binary("<", id("py"), binary("+", id("y"), id("height")))
            )
          )
        )
      )
    )).with_prefix_modifiers("const "),
    
    # Rect area method
    function_decl("float", "area", [], block(
      return_stmt(binary("*", id("width"), id("height")))
    )).with_prefix_modifiers("const "),
    
    # Color struct - Product type
    product_type("Color",
      field_def("r", "float"),
      field_def("g", "float"),
      field_def("b", "float"),
      field_def("a", "float")
    ),
    
    # Color constructor
    function_decl("", "Color", [], block(
      # Default constructor
    )).with_suffix(" = default"),
    
    function_decl("", "Color", [
      param("float", "r_"),
      param("float", "g_"),
      param("float", "b_"),
      param("float", "a_ = 1.0f")
    ], block(
      expr_stmt(binary("=", id("r"), id("r_"))),
      expr_stmt(binary("=", id("g"), id("g_"))),
      expr_stmt(binary("=", id("b"), id("b_"))),
      expr_stmt(binary("=", id("a"), id("a_")))
    )).with_prefix_modifiers("constexpr "),
    
    # Color static factory methods
    function_decl("Color", "white", [], block(
      return_stmt(
        # {1.0f, 1.0f, 1.0f, 1.0f}
        float(1.0),
        float(1.0),
        float(1.0),
        float(1.0)
      )
    )).with_prefix_modifiers("static constexpr "),
    
    function_decl("Color", "black", [], block(
      return_stmt(
        float(0.0),
        float(0.0),
        float(0.0),
        float(1.0)
      )
    )).with_prefix_modifiers("static constexpr "),
    
    function_decl("Color", "red", [], block(
      return_stmt(
        float(1.0),
        float(0.0),
        float(0.0),
        float(1.0)
      )
    )).with_prefix_modifiers("static constexpr "),
    
    # GlyphMetrics struct - Product type
    product_type("GlyphMetrics",
      field_def("size", "Vec2"),
      field_def("bearing", "Vec2"),
      field_def("advance", "Vec2")
    ),
    
    # AtlasFormat enum class
    enum_decl("AtlasFormat", [
      ["A8", "0"],
      ["RGB8", "1"],
      ["RGBA8", "2"]
    ], class_keyword: "class"),
    
    # RenderMode enum class
    enum_decl("RenderMode", [
      ["BITMAP", "0"],
      ["MSDF", "1"],
      ["SDF", "2"]
    ], class_keyword: "class"),
    
    # AtlasSlot struct - Product type
    product_type("AtlasSlot",
      field_def("page_id", "AtlasPageID"),
      field_def("texture_id", "TextureID"),
      field_def("pixel_rect", "Rect"),
      field_def("uv_rect", "Rect")
    ),
    
    # AtlasSlot is_valid method
    function_decl("bool", "is_valid", [], block(
      return_stmt(binary("!=", id("texture_id"), int(0)))
    )).with_prefix_modifiers("const "),
    
    # GlyphCacheKey struct - Product type
    product_type("GlyphCacheKey",
      field_def("font_id", "FontFaceID"),
      field_def("glyph_index", "GlyphIndex"),
      field_def("size_px", "uint16_t"),
      field_def("mode", "RenderMode")
    ),
    
    # GlyphCacheKey operator==
    function_decl("bool", "operator==", [param(borrowed("GlyphCacheKey"), "other")], block(
      return_stmt(
        binary("&&",
          binary("==", id("font_id"), member(id("other"), ".", "font_id")),
          binary("&&",
            binary("==", id("glyph_index"), member(id("other"), ".", "glyph_index")),
            binary("&&",
              binary("==", id("size_px"), member(id("other"), ".", "size_px")),
              binary("==", id("mode"), member(id("other"), ".", "mode"))
            )
          )
        )
      )
    )).with_prefix_modifiers("const "),
    
    # CachedGlyph struct - Product type
    product_type("CachedGlyph",
      field_def("key", "GlyphCacheKey"),
      field_def("metrics", "GlyphMetrics"),
      field_def("atlas_slot", "AtlasSlot"),
      field_def("last_used_frame", "uint64_t")
    ),
    
    # CachedGlyph is_valid method
    function_decl("bool", "is_valid", [], block(
      return_stmt(call(member(id("atlas_slot"), ".", "is_valid")))
    )).with_prefix_modifiers("const "),
    
    # ShapedGlyph struct - Product type
    product_type("ShapedGlyph",
      field_def("glyph_index", "GlyphIndex"),
      field_def("offset", "Vec2"),
      field_def("advance", "Vec2"),
      field_def("cluster", "uint32_t")
    ),
    
    # FontStyle struct - Product type
    product_type("FontStyle",
      field_def("size_px", "uint16_t"),
      field_def("render_mode", "RenderMode")
    ),
    
    # FontStyle auto_mode static method
    function_decl("RenderMode", "auto_mode", [param("uint16_t", "size_px")], block(
      return_stmt(
        ternary(
          binary(">=", id("size_px"), int(24)),
          member(id("RenderMode"), "::", "MSDF"),
          member(id("RenderMode"), "::", "BITMAP")
        )
      )
    )).with_prefix_modifiers("static "),
    
    # RasterizedGlyph struct - Product type
    product_type("RasterizedGlyph",
      field_def("bitmap", "std::vector<uint8_t>"),
      field_def("width", "uint32_t"),
      field_def("height", "uint32_t"),
      field_def("metrics", "GlyphMetrics"),
      field_def("format", "AtlasFormat")
    ),
    
    # DrawGlyph struct - Product type
    product_type("DrawGlyph",
      field_def("texture_id", "TextureID"),
      field_def("position_rect", "Rect"),
      field_def("uv_rect", "Rect"),
      field_def("color", "Color"),
      field_def("px_range", "float"),
      field_def("mode", "RenderMode")
    )
  ])
)

puts "Generated C++ Code:"
puts "=" * 80
puts ast.to_source
puts "=" * 80

puts
puts "Features demonstrated:"
puts "✅ Product types for mathematical structures (Vec2, Rect, Color)"
puts "✅ Enum classes with values"
puts "✅ Operator overloading (+, -, *, +=)"
puts "✅ Constexpr constructors and methods"
puts "✅ Static factory methods"
puts "✅ Method implementations with logic"
puts "✅ Complex boolean expressions"
puts "✅ Ternary operators"
puts "✅ Member access patterns"

puts
puts "Benefits of using Aurora DSL for types:"
puts "• Automatic generation of consistent operator overloads"
puts "• Type-safe mathematical operations"
puts "• Constexpr optimization by default"
puts "• Easy refactoring - change field types in one place"
puts "• Guaranteed consistency across all similar types"
puts "• Modern C++ best practices enforced"
puts "• Reduced boilerplate code"
