#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/cpp_ast"
require_relative "../../lib/cpp_ast/builder/dsl_v2"

include CppAst::Builder::DSLv2

puts "=== DSL v2: Ownership Types ==="
puts "Demonstrating ownership types and memory management"
puts

# Example 1: Basic ownership
puts "=== Example 1: Basic Ownership ==="
ast = program do
  # Function taking owned resource
  fn :process_buffer, 
     params: [[t.owned(:Buffer), :buf]], 
     ret: t.i32,
     noexcept: true do
    ret id(:buf).call(:size)
  end
  
  # Function taking borrowed resource
  fn :read_config, 
     params: [[t.borrowed(:Config), :config]], 
     ret: t.string,
     const: true,
     noexcept: true do
    ret id(:config).call(:get_value, string("setting"))
  end
  
  # Function taking mutable borrowed resource
  fn :update_state, 
     params: [[t.mut_borrowed(:State), :state]], 
     ret: t.void,
     noexcept: true do
    id(:state).call(:set_dirty, bool(true))
  end
end

puts ast.to_node.to_source
puts

# Example 2: Container ownership
puts "=== Example 2: Container Ownership ==="
ast = program do
  # Function with span (borrowed view)
  fn :sum_array, 
     params: [[t.span(t.f32), :numbers]], 
     ret: t.f32,
     constexpr: true,
     noexcept: true do
    let_ :sum, float(0.0)
    for_range :it, id(:numbers) do
      id(:sum) = id(:sum) + deref(id(:it))
    end
    ret id(:sum)
  end
  
  # Function with const span
  fn :count_positive, 
     params: [[t.span_const(t.f32), :numbers]], 
     ret: t.i32,
     constexpr: true,
     noexcept: true do
    let_ :count, int(0)
    for_range :it, id(:numbers) do
      if_ deref(id(:it)) > float(0.0) do
        id(:count) = id(:count) + int(1)
      end
    end
    ret id(:count)
  end
  
  # Function returning owned container
  fn :create_vector, 
     params: [[:i32, :size]], 
     ret: t.owned(t.vec(t.f32)),
     noexcept: true do
    ret new(t.vec(t.f32), id(:size))
  end
end

puts ast.to_node.to_source
puts

# Example 3: Result/Option types
puts "=== Example 3: Result/Option Types ==="
ast = program do
  # Function returning Result
  fn :safe_divide, 
     params: [[:f32, :a], [:f32, :b]], 
     ret: t.result(t.f32, t.string),
     noexcept: true do
    if_ id(:b) == float(0.0) do
      ret err(string("Division by zero"))
    else_
      ret ok(id(:a) / id(:b))
    end
  end
  
  # Function returning Option
  fn :find_element, 
     params: [[t.span(t.i32), :arr], [:i32, :value]], 
     ret: t.option(t.i32),
     noexcept: true do
    for_range :it, id(:arr) do
      if_ deref(id(:it)) == id(:value) do
        ret some(deref(id(:it)))
      end
    end
    ret none
  end
  
  # Function using Result
  fn :calculate_average, 
     params: [[t.span(t.f32), :numbers]], 
     ret: t.result(t.f32, t.string),
     noexcept: true do
    if_ id(:numbers).call(:empty) do
      ret err(string("Empty array"))
    else_
      let_ :sum, float(0.0)
      for_range :it, id(:numbers) do
        id(:sum) = id(:sum) + deref(id(:it))
      end
      ret ok(id(:sum) / cast(t.f32, id(:numbers).call(:size)))
    end
  end
end

puts ast.to_node.to_source
puts

# Example 4: Smart pointers
puts "=== Example 4: Smart Pointers ==="
ast = program do
  # Function with unique_ptr
  fn :create_resource, 
     params: [[:i32, :size]], 
     ret: t.owned(:Resource),
     noexcept: true do
    ret new(t.Resource, id(:size))
  end
  
  # Function with shared_ptr
  fn :share_resource, 
     params: [[t.owned(:Resource), :resource]], 
     ret: t.shared(:Resource),
     noexcept: true do
    ret call(:std, :make_shared, t.Resource, id(:resource))
  end
  
  # Function with weak_ptr
  fn :check_resource, 
     params: [[t.weak(:Resource), :resource]], 
     ret: t.bool,
     noexcept: true do
    ret id(:resource).call(:expired) == bool(false)
  end
end

puts ast.to_node.to_source
puts

# Example 5: RAII class
puts "=== Example 5: RAII Class ==="
ast = program do
  class_ :ResourceManager do
    field :resource, t.owned(:Resource)
    field :is_valid, t.bool, default: bool(false)
    
    # Constructor
    ctor params: [[:i32, :size]], 
         noexcept: true do
      id(:self).member(:resource) = new(t.Resource, id(:size))
      id(:self).member(:is_valid) = bool(true)
    end
    
    # Move constructor
    ctor params: [[t.ref(:ResourceManager, mutable: true), :other]], 
         noexcept: true do
      id(:self).member(:resource) = id(:other).member(:resource)
      id(:self).member(:is_valid) = id(:other).member(:is_valid)
      id(:other).member(:resource) = nullptr
      id(:other).member(:is_valid) = bool(false)
    end
    
    # Move assignment
    def_ :operator=, 
         params: [[t.ref(:ResourceManager, mutable: true), :other]], 
         ret: t.ref(:ResourceManager),
         noexcept: true do
      if_ id(:self) != id(:other) do
        if_ id(:self).member(:is_valid) do
          delete id(:self).member(:resource)
        end
        id(:self).member(:resource) = id(:other).member(:resource)
        id(:self).member(:is_valid) = id(:other).member(:is_valid)
        id(:other).member(:resource) = nullptr
        id(:other).member(:is_valid) = bool(false)
      end
      ret id(:self)
    end
    
    # Destructor
    dtor noexcept: true do
      if_ id(:self).member(:is_valid) do
        delete id(:self).member(:resource)
      end
    end
    
    # Member functions
    def_ :is_valid, 
         ret: t.bool, 
         const: true, 
         noexcept: true do
      ret id(:self).member(:is_valid)
    end
    
    def_ :get_resource, 
         ret: t.ref(:Resource, const: true), 
         const: true, 
         noexcept: true do
      ret deref(id(:self).member(:resource))
    end
    
    def_ :get_resource_mut, 
         ret: t.ref(:Resource, mutable: true), 
         noexcept: true do
      ret deref(id(:self).member(:resource))
    end
  end
end

puts ast.to_node.to_source
puts

# Example 6: Variant types
puts "=== Example 6: Variant Types ==="
ast = program do
  # Sum type using variant
  type_alias :Shape, t.variant(t.Circle, t.Rect, t.Polygon)
  
  # Function with variant
  fn :calculate_area, 
     params: [[t.Shape, :shape]], 
     ret: t.f32,
     noexcept: true do
    match_ id(:shape) do
      case_ t.Circle, [:r] do
        ret float(3.14159) * id(:r) * id(:r)
      end
      case_ t.Rect, [:w, :h] do
        ret id(:w) * id(:h)
      end
      case_ t.Polygon, [:points] do
        ret float(0.0)  # Simplified
      end
    end
  end
  
  # Function creating variant
  fn :create_circle, 
     params: [[:f32, :radius]], 
     ret: t.Shape,
     noexcept: true do
    ret call(:std, :make_variant, t.Circle, id(:radius))
  end
end

puts ast.to_node.to_source
puts

puts "=== Features demonstrated ==="
puts "✅ Owned types (unique_ptr)"
puts "✅ Borrowed types (const T&, T&)"
puts "✅ Span types (std::span<T>)"
puts "✅ Result types (std::expected<T, E>)"
puts "✅ Option types (std::optional<T>)"
puts "✅ Smart pointers (shared_ptr, weak_ptr)"
puts "✅ RAII with proper resource management"
puts "✅ Variant types (std::variant<Ts...>)"
puts "✅ Pattern matching with variants"
puts "✅ Exception safety (noexcept)"
puts

puts "Demo completed successfully! 🎉"
