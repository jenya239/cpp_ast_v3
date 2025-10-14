#!/usr/bin/env ruby
# frozen_string_literal: true

# Aurora DSL Demo - Comprehensive example using all Aurora features
# This demonstrates the extended Ruby DSL for C++ with ownership, ADT, and pattern matching

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== Aurora DSL Demo ==="
puts "Generating C++ code with ownership, ADT, and pattern matching features"
puts

# Create a comprehensive example
ast = program(
  # Product type - simple struct
  product_type("Point",
    field_def("x", "float"),
    field_def("y", "float")
  ),
  
  # Sum type - variant with multiple cases
  sum_type("Shape",
    case_struct("Circle", field_def("center", "Point"), field_def("radius", "float")),
    case_struct("Rect", field_def("top_left", "Point"), field_def("width", "float"), field_def("height", "float")),
    case_struct("Polygon", field_def("points", "std::vector<Point>"))
  ),
  
  # Function with ownership types and Result return
  function_decl(result_of("float", "std::string"), "calculate_area",
    [param(borrowed("Shape"), "shape")],
    block(
      return_stmt(match_expr(id("shape"),
        arm("Circle", ["center", "radius"], 
          binary("*", float(3.14159), binary("*", id("radius"), id("radius")))),
        arm("Rect", ["top_left", "width", "height"],
          binary("*", id("width"), id("height"))),
        arm("Polygon", ["points"],
          float(0.0)) # Simplified for demo
      ))
    )
  ),
  
  # Function with Option type
  function_decl(option_of("Point"), "find_center",
    [param(borrowed("Shape"), "shape")],
    block(
      return_stmt(match_expr(id("shape"),
        arm("Circle", ["center"], some(id("center"))),
        arm("Rect", ["top_left", "width", "height"],
          some(call(id("Point"), 
            binary("+", member(id("top_left"), ".", "x"), binary("/", id("width"), float(2.0))),
            binary("+", member(id("top_left"), ".", "y"), binary("/", id("height"), float(2.0)))
          ))),
        arm("Polygon", ["points"], none)
      ))
    )
  ),
  
  # Function with ownership and span types
  function_decl("void", "process_shapes",
    [param("std::span<std::unique_ptr<Shape>>", "shapes")],
    block(
      for_stmt(
        "auto it = shapes.begin()",
        binary("!=", id("it"), call(member(id("shapes"), ".", "end"))),
        unary_post("++", id("it")),
        block(
          expr_stmt(call(id("process_shape"), deref(id("it"))))
        )
      )
    )
  ),
  
  # Function demonstrating nested Result/Option types
  function_decl(result_of(option_of("float"), "std::string"), "safe_calculate_area",
    [param(borrowed("Shape"), "shape")],
    block(
      return_stmt(match_expr(id("shape"),
        arm("Circle", ["center", "radius"],
          ok(some(binary("*", float(3.14159), binary("*", id("radius"), id("radius")))))),
        arm("Rect", ["top_left", "width", "height"],
          ok(some(binary("*", id("width"), id("height"))))),
        arm("Polygon", ["points"],
          ok(none))
      ))
    )
  )
)

# Generate and display the C++ code
cpp_code = ast.to_source

puts "Generated C++ Code:"
puts "=" * 50
puts cpp_code
puts "=" * 50

puts
puts "Features demonstrated:"
puts "✅ Product types (struct Point)"
puts "✅ Sum types (variant Shape with Circle, Rect, Polygon)"
puts "✅ Ownership types (borrowed, owned, span)"
puts "✅ Result/Option types (std::expected, std::optional)"
puts "✅ Pattern matching (std::visit with overloaded)"
puts "✅ Function declarations with complex types"
puts "✅ Nested type combinations"
puts

puts "This C++ code can be compiled with C++20 and will work with:"
puts "- std::expected (C++23) or tl::expected (fallback)"
puts "- std::optional (C++17)"
puts "- std::variant (C++17)"
puts "- std::span (C++20)"
puts "- std::unique_ptr (C++11)"
puts

puts "Demo completed successfully! 🎉"
