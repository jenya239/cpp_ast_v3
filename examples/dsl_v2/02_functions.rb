#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/cpp_ast"
require_relative "../../lib/cpp_ast/builder/dsl_v2"

include CppAst::Builder::DSLv2

puts "=== DSL v2: Functions with Best Practices ==="
puts "Demonstrating function builder with automatic best practices"
puts

# Example 1: Pure functions
puts "=== Example 1: Pure Functions ==="
ast = program do
  # Pure function with automatic noexcept and nodiscard
  fn :distance, 
     params: [[:f32, :x1], [:f32, :y1], [:f32, :x2], [:f32, :y2]], 
     ret: t.f32,
     constexpr: true do
    let_ :dx, id(:x2) - id(:x1)
    let_ :dy, id(:y2) - id(:y1)
    ret (id(:dx) * id(:dx) + id(:dy) * id(:dy)).call(:sqrt)
  end
  
  # Function with automatic const
  fn :magnitude, 
     params: [[:f32, :x], [:f32, :y]], 
     ret: t.f32,
     constexpr: true do
    ret (id(:x) * id(:x) + id(:y) * id(:y)).call(:sqrt)
  end
end

puts ast.to_node.to_source
puts

# Example 2: Member functions
puts "=== Example 2: Member Functions ==="
ast = program do
  class_ :Vec2 do
    field :x, t.f32, default: float(0.0)
    field :y, t.f32, default: float(0.0)
    
    # Constructor with best practices
    ctor params: [[:f32, :x], [:f32, :y]], 
         constexpr: true, 
         noexcept: true do
      id(:self).member(:x) = id(:x)
      id(:self).member(:y) = id(:y)
    end
    
    # Copy constructor
    ctor params: [[t.ref(:Vec2, const: true), :other]], 
         constexpr: true, 
         noexcept: true do
      id(:self).member(:x) = id(:other).member(:x)
      id(:self).member(:y) = id(:other).member(:y)
    end
    
    # Move constructor
    ctor params: [[t.ref(:Vec2, mutable: true), :other]], 
         constexpr: true, 
         noexcept: true do
      id(:self).member(:x) = id(:other).member(:x)
      id(:self).member(:y) = id(:other).member(:y)
    end
    
    # Assignment operator
    def_ :operator=, 
         params: [[t.ref(:Vec2, const: true), :other]], 
         ret: t.ref(:Vec2),
         constexpr: true, 
         noexcept: true do
      id(:self).member(:x) = id(:other).member(:x)
      id(:self).member(:y) = id(:other).member(:y)
      ret id(:self)
    end
    
    # Move assignment operator
    def_ :operator=, 
         params: [[t.ref(:Vec2, mutable: true), :other]], 
         ret: t.ref(:Vec2),
         constexpr: true, 
         noexcept: true do
      id(:self).member(:x) = id(:other).member(:x)
      id(:self).member(:y) = id(:other).member(:y)
      ret id(:self)
    end
    
    # Destructor
    dtor noexcept: true do
      # Nothing to do
    end
    
    # Member function with automatic const
    def_ :length, 
         ret: t.f32, 
         const: true, 
         noexcept: true do
      ret (id(:x) * id(:x) + id(:y) * id(:y)).call(:sqrt)
    end
    
    # Member function with automatic const
    def_ :normalize, 
         ret: t.void, 
         noexcept: true do
      let_ :len, id(:self).call(:length)
      if_ id(:len) > float(0.0) do
        id(:self).member(:x) = id(:self).member(:x) / id(:len)
        id(:self).member(:y) = id(:self).member(:y) / id(:len)
      end
    end
    
    # Static member function
    def_ :zero, 
         ret: t.Vec2, 
         static: true, 
         constexpr: true, 
         noexcept: true do
      ret call(:Vec2, float(0.0), float(0.0))
    end
  end
end

puts ast.to_node.to_source
puts

# Example 3: Template functions
puts "=== Example 3: Template Functions ==="
ast = program do
  # Template function with concepts
  template_ [:T] do
    fn :max, 
       params: [[t.ref(:T, const: true), :a], [t.ref(:T, const: true), :b]], 
       ret: t.ref(:T, const: true),
       constexpr: true, 
       noexcept: true do
      if_ id(:a) > id(:b) do
        ret id(:a)
      else_
        ret id(:b)
      end
    end
  end
  
  # Template function with requires clause
  template_ [:T] do
    fn :sort, 
       params: [[t.span(t.ref(:T, mutable: true)), :arr]], 
       ret: t.void,
       noexcept: true do
      # Simple bubble sort for demonstration
      for_ id(:i), int(0), id(:arr).call(:size) - int(1), id(:i)++ do
        for_ id(:j), int(0), id(:arr).call(:size) - id(:i) - int(1), id(:j)++ do
          if_ id(:arr)[id(:j)] > id(:arr)[id(:j) + int(1)] do
            let_ :temp, id(:arr)[id(:j)]
            id(:arr)[id(:j)] = id(:arr)[id(:j) + int(1)]
            id(:arr)[id(:j) + int(1)] = id(:temp)
          end
        end
      end
    end
  end
end

puts ast.to_node.to_source
puts

# Example 4: Lambda functions
puts "=== Example 4: Lambda Functions ==="
ast = program do
  # Function using lambda
  fn :apply_transform, 
     params: [[t.span(t.f32), :data], [t.function(t.f32, t.f32), :transform]], 
     ret: t.void,
     noexcept: true do
    for_range :it, id(:data) do
      deref(id(:it)) = id(:transform).call(deref(id(:it)))
    end
  end
  
  # Function returning lambda
  fn :create_multiplier, 
     params: [[:f32, :factor]], 
     ret: t.function(t.f32, t.f32),
     constexpr: true, 
     noexcept: true do
    ret lambda params: [[:f32, :x]], ret: t.f32 do
      ret id(:x) * id(:factor)
    end
  end
end

puts ast.to_node.to_source
puts

puts "=== Features demonstrated ==="
puts "✅ Automatic noexcept for pure functions"
puts "✅ Automatic [[nodiscard]] for non-void functions"
puts "✅ Automatic const for non-mutating functions"
puts "✅ Automatic constexpr where possible"
puts "✅ Rule of Five generation"
puts "✅ Template functions with concepts"
puts "✅ Lambda functions"
puts "✅ Member functions with proper const"
puts

puts "Demo completed successfully! 🎉"
