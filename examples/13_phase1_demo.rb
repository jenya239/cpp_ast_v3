#!/usr/bin/env ruby
# frozen_string_literal: true

# Phase 1 Demo - Virtual Methods, Inheritance, Attributes
# Demonstrates new DSL capabilities added in Phase 1

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== Phase 1 Demo - New DSL Capabilities ==="
puts "Testing virtual methods, inheritance, and C++11 attributes"
puts

# Demo 1: Virtual Methods
puts "1. Virtual Methods Demo:"
puts "=" * 40

abstract_base = class_with_inheritance("AbstractBase", [], 
  function_decl("void", "pure_virtual_method", [], nil).pure_virtual(),
  function_decl("void", "virtual_method", [], block(
    expr_stmt(call(id("std::cout")) << string("Base implementation"))
  )).virtual(),
  function_decl("", "~AbstractBase", [], block()).virtual()
)

puts "Abstract Base Class:"
puts abstract_base.to_source
puts

# Demo 2: Inheritance with Override
puts "2. Inheritance with Override Demo:"
puts "=" * 40

concrete_derived = class_with_inheritance("ConcreteDerived", ["public AbstractBase"], 
  function_decl("void", "pure_virtual_method", [], block(
    expr_stmt(call(id("std::cout")) << string("Derived implementation"))
  )).override(),
  function_decl("void", "virtual_method", [], block(
    expr_stmt(call(id("std::cout")) << string("Derived override"))
  )).override(),
  function_decl("", "~ConcreteDerived", [], block()).override()
)

puts "Concrete Derived Class:"
puts concrete_derived.to_source
puts

# Demo 3: C++11 Attributes
puts "3. C++11 Attributes Demo:"
puts "=" * 40

attributes_demo = class_decl("AttributesDemo",
  function_decl("int", "compute", [param("int", "x"), param("int", "y")], block(
    return_stmt(binary("*", id("x"), id("y")))
  )).nodiscard().maybe_unused(),
  
  function_decl("void", "old_api", [], block()).deprecated_with_message("Use new_api instead"),
  
  function_decl("void", "new_api", [], block()).attribute("api_version").attribute("stable"),
  
  function_decl("void", "unused_function", [], block()).maybe_unused()
)

puts "Attributes Demo Class:"
puts attributes_demo.to_source
puts

# Demo 4: Complex Inheritance Hierarchy
puts "4. Complex Inheritance Hierarchy Demo:"
puts "=" * 40

complex_hierarchy = program(
  # Base interface
  class_with_inheritance("Drawable", [],
    function_decl("void", "draw", [], nil).pure_virtual(),
    function_decl("void", "update", [param("float", "delta_time")], block()).virtual()
  ),
  
  # Intermediate base
  class_with_inheritance("Shape", ["public Drawable"],
    function_decl("void", "draw", [], block(
      expr_stmt(call(id("std::cout")) << string("Drawing shape"))
    )).override(),
    function_decl("float", "area", [], nil).pure_virtual()
  ),
  
  # Concrete implementation
  class_with_inheritance("Circle", ["public Shape"],
    function_decl("float", "area", [], block(
      return_stmt(binary("*", float(3.14159), binary("*", id("radius_"), id("radius_"))))
    )).override(),
    function_decl("void", "update", [param("float", "delta_time")], block(
      expr_stmt(call(id("std::cout")) << string("Circle updating"))
    )).override().final()
  )
)

puts "Complex Inheritance Hierarchy:"
puts complex_hierarchy.to_source
puts

# Demo 5: Modern C++ Features Combined
puts "5. Modern C++ Features Combined Demo:"
puts "=" * 40

modern_features = class_with_inheritance("ModernClass", ["public Drawable"],
  # Static constexpr method
  function_decl("int", "version", [], block(return_stmt(int(1)))).static().constexpr().nodiscard(),
  
  # Explicit constructor with attributes
  function_decl("", "ModernClass", [param("int", "id")], block(
    expr_stmt(binary("=", id("id_"), id("id")))
  )).explicit().attribute("api_version"),
  
  # Deleted copy constructor
  function_decl("", "ModernClass", [param(borrowed("ModernClass"), "other")], nil).deleted(),
  
  # Move constructor with noexcept
  function_decl("", "ModernClass", [param("ModernClass&&", "other")], block(
    expr_stmt(binary("=", id("id_"), member(id("other"), ".", "id_"))),
    expr_stmt(binary("=", member(id("other"), ".", "id_"), int(0)))
  )).noexcept(),
  
  # Virtual override with final
  function_decl("void", "draw", [], block(
    expr_stmt(call(id("std::cout")) << string("Modern drawing"))
  )).override().final(),
  
  # Const method with attributes
  function_decl("int", "get_id", [], block(return_stmt(id("id_")))).const().nodiscard(),
  
  # Deprecated method
  function_decl("void", "old_draw", [], block()).deprecated().maybe_unused(),
  
  access_spec("private"),
  var_decl("int", "id_")
)

puts "Modern C++ Features Combined:"
puts modern_features.to_source
puts

puts "Phase 1 Demo completed successfully! 🎉"
puts
puts "New capabilities demonstrated:"
puts "✅ Virtual methods (.virtual(), .override(), .final(), .pure_virtual())"
puts "✅ Class inheritance (.class_with_inheritance())"
puts "✅ C++11 attributes (.attribute(), .maybe_unused(), .deprecated())"
puts "✅ Combined with existing modifiers (.const(), .noexcept(), .nodiscard())"
puts "✅ Complex inheritance hierarchies"
puts "✅ Modern C++ patterns (RAII, move semantics, deleted copy)"
puts
puts "Ready for real-world C++ code generation! 🚀"
