#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/cpp_ast"

include CppAst::Builder::DSL

puts "=== Phase 4 Demo: Advanced C++ Features ==="
puts

# 1. Advanced Templates
puts "1. Advanced Templates:"
puts "====================="

# Variadic template class
variadic_class = variadic_template_class("Tuple", "T")
puts "Variadic template class:"
puts variadic_class.to_source
puts

# Variadic template function
variadic_func = variadic_template_function("void", "print_all", "T")
puts "Variadic template function:"
puts variadic_func.to_source
puts

# Template template parameter
template_param = template_template_param("Container", ["typename T"])
puts "Template template parameter:"
puts template_param
puts

# 2. C++20 Concepts
puts "2. C++20 Concepts:"
puts "=================="

# Simple concept
drawable_concept = concept_decl("Drawable", ["typename T"], "requires(T t) { t.draw(); }")
puts "Simple concept:"
puts drawable_concept.to_source
puts

# Concept with multiple requirements
serializable_concept = concept_decl("Serializable", 
  ["typename T"], 
  "requires(T t) { t.serialize(); t.deserialize(); }"
)
puts "Complex concept:"
puts serializable_concept.to_source
puts

# 3. C++20 Modules
puts "3. C++20 Modules:"
puts "================="

# Module declaration
math_module = module_decl("math",
  import_decl("std.core"),
  var_decl("double", "PI", "3.14159"),
  function_decl("double", "sqrt", [param("double", "x")], block(
    return_stmt(call(id("std::sqrt"), [id("x")]))
  ))
)
puts "Module declaration:"
puts math_module.to_source
puts

# Import declaration
import_stmt = import_decl("std.threading")
puts "Import declaration:"
puts import_stmt.to_source
puts

# Export declaration
export_stmt = export_decl(
  var_decl("int", "VERSION", "1"),
  function_decl("void", "init", [], nil)
)
puts "Export declaration:"
puts export_stmt.to_source
puts

# 4. C++20 Coroutines
puts "4. C++20 Coroutines:"
puts "===================="

# Coroutine function
generator = coroutine_function("int", "fibonacci", [param("int", "n")], block(
  co_yield(int(0)),
  co_yield(int(1)),
  co_return(int(0))
))
puts "Coroutine function:"
puts generator.to_source
puts

# Co-await expression
await_expr = co_await(call(id("async_task"), "get", []))
puts "Co-await expression:"
puts await_expr.to_source
puts

# Co-yield expression
yield_expr = co_yield(int(42))
puts "Co-yield expression:"
puts yield_expr.to_source
puts

# Co-return statement
co_return_stmt = co_return(int(100))
puts "Co-return statement:"
puts co_return_stmt.to_source
puts

# 5. Performance Optimization
puts "5. Performance Optimization:"
puts "============================"

# Create optimized DSL compiler
require_relative "../lib/cpp_ast/builder/cache"
optimized_dsl = CppAst::Builder::OptimizedDSL.new

# Compile some code
3.times do |i|
  result = optimized_dsl.compile("int(#{i * 10})")
  puts "Compiled: #{result}"
end

# Compile the same code again (should be cached)
result = optimized_dsl.compile("int(0)")
puts "Compiled (cached): #{result}"

# Show stats
stats = optimized_dsl.stats
puts "\nPerformance Stats:"
puts "  Total compilations: #{stats[:compilation][:total_compilations]}"
puts "  Cached compilations: #{stats[:compilation][:cached_compilations]}"
puts "  Cache hit rate: #{(stats[:cache][:hit_rate] * 100).round(2)}%"
puts "  Average compilation time: #{(stats[:compilation][:average_time] * 1000).round(2)}ms"
puts

# 6. Complex Example: Async Graphics Library
puts "6. Complex Example - Async Graphics Library:"
puts "============================================="

graphics_lib = program(
  # Module declaration
  module_decl("graphics",
    import_decl("std.core"),
    import_decl("std.threading"),
    
    # Concept for drawable objects
    concept_decl("Drawable", ["typename T"], "requires(T t) { t.draw(); t.resize(int, int); }"),
    
    # Variadic template class for scene graph
    variadic_template_class("SceneNode", "T"),
    
    # Coroutine for async rendering
    coroutine_function("void", "render_async", [param("int", "frame_count")], block(
      co_yield(int(1)),
      co_return()
    )),
    
    # Export declarations
    export_decl(
      function_decl("void", "render_async", [param("int", "frame_count")], nil)
    )
  )
)

puts "Generated Graphics Library Module:"
puts graphics_lib.to_source
puts

puts "=== Phase 4 Demo Complete ==="
puts "✅ Advanced Templates: variadic, template template parameters"
puts "✅ C++20 Concepts: type constraints"
puts "✅ C++20 Modules: import/export"
puts "✅ C++20 Coroutines: co_await, co_yield, co_return"
puts "✅ Performance: compilation caching and optimization"
puts "✅ Complex Patterns: Async Graphics Library with modern C++ features"
