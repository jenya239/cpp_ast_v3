#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/cpp_ast"
require_relative "../../lib/cpp_ast/builder/dsl_v2"

include CppAst::Builder::DSLv2

puts "=== DSL v2: Classes with Best Practices ==="
puts "Demonstrating class builder with automatic best practices"
puts

# Example 1: Basic class with rule of five
puts "=== Example 1: Basic Class with Rule of Five ==="
ast = program do
  class_ :Point do
    field :x, t.f32, default: float(0.0)
    field :y, t.f32, default: float(0.0)
    
    # Generate rule of five automatically
    rule_of_five!
    
    # Custom constructor
    ctor params: [[:f32, :x], [:f32, :y]], 
         constexpr: true, 
         noexcept: true do
      id(:self).member(:x) = id(:x)
      id(:self).member(:y) = id(:y)
    end
    
    # Member functions
    def_ :distance_to, 
         params: [[t.ref(:Point, const: true), :other]], 
         ret: t.f32, 
         const: true, 
         noexcept: true do
      let_ :dx, id(:self).member(:x) - id(:other).member(:x)
      let_ :dy, id(:self).member(:y) - id(:other).member(:y)
      ret (id(:dx) * id(:dx) + id(:dy) * id(:dy)).call(:sqrt)
    end
    
    def_ :move, 
         params: [[:f32, :dx], [:f32, :dy]], 
         ret: t.void, 
         noexcept: true do
      id(:self).member(:x) = id(:self).member(:x) + id(:dx)
      id(:self).member(:y) = id(:self).member(:y) + id(:dy)
    end
  end
end

puts ast.to_node.to_source
puts

# Example 2: Abstract base class
puts "=== Example 2: Abstract Base Class ==="
ast = program do
  class_ :Shape, abstract: true do
    # Pure virtual function
    def_ :area, 
         ret: t.f32, 
         const: true, 
         virtual: true, 
         pure_virtual: true do
      # Pure virtual - no implementation
    end
    
    # Pure virtual function
    def_ :perimeter, 
         ret: t.f32, 
         const: true, 
         virtual: true, 
         pure_virtual: true do
      # Pure virtual - no implementation
    end
    
    # Virtual destructor
    dtor virtual: true, noexcept: true do
      # Virtual destructor
    end
  end
end

puts ast.to_node.to_source
puts

# Example 3: Derived class
puts "=== Example 3: Derived Class ==="
ast = program do
  class_ :Circle do
    inherits :Shape, access: :public
    
    field :radius, t.f32, default: float(0.0)
    
    # Constructor
    ctor params: [[:f32, :radius]], 
         constexpr: true, 
         noexcept: true do
      id(:self).member(:radius) = id(:radius)
    end
    
    # Override virtual function
    def_ :area, 
         ret: t.f32, 
         const: true, 
         override: true, 
         noexcept: true do
      ret float(3.14159) * id(:radius) * id(:radius)
    end
    
    # Override virtual function
    def_ :perimeter, 
         ret: t.f32, 
         const: true, 
         override: true, 
         noexcept: true do
      ret float(2.0) * float(3.14159) * id(:radius)
    end
    
    # Final destructor
    dtor final: true, noexcept: true do
      # Final destructor
    end
  end
end

puts ast.to_node.to_source
puts

# Example 4: Template class
puts "=== Example 4: Template Class ==="
ast = program do
  template_class [:T], :Vector do
    field :data, t.span(t.ref(:T, mutable: true))
    field :size, t.i32, default: int(0)
    
    # Constructor
    ctor params: [[t.span(t.ref(:T, mutable: true)), :data], [:i32, :size]], 
         constexpr: true, 
         noexcept: true do
      id(:self).member(:data) = id(:data)
      id(:self).member(:size) = id(:size)
    end
    
    # Copy constructor
    ctor params: [[t.ref(:Vector, const: true), :other]], 
         constexpr: true, 
         noexcept: true do
      id(:self).member(:data) = id(:other).member(:data)
      id(:self).member(:size) = id(:other).member(:size)
    end
    
    # Move constructor
    ctor params: [[t.ref(:Vector, mutable: true), :other]], 
         constexpr: true, 
         noexcept: true do
      id(:self).member(:data) = id(:other).member(:data)
      id(:self).member(:size) = id(:other).member(:size)
    end
    
    # Assignment operator
    def_ :operator=, 
         params: [[t.ref(:Vector, const: true), :other]], 
         ret: t.ref(:Vector),
         constexpr: true, 
         noexcept: true do
      id(:self).member(:data) = id(:other).member(:data)
      id(:self).member(:size) = id(:other).member(:size)
      ret id(:self)
    end
    
    # Move assignment operator
    def_ :operator=, 
         params: [[t.ref(:Vector, mutable: true), :other]], 
         ret: t.ref(:Vector),
         constexpr: true, 
         noexcept: true do
      id(:self).member(:data) = id(:other).member(:data)
      id(:self).member(:size) = id(:other).member(:size)
      ret id(:self)
    end
    
    # Destructor
    dtor noexcept: true do
      # Nothing to do
    end
    
    # Member functions
    def_ :at, 
         params: [[:i32, :index]], 
         ret: t.ref(:T, mutable: true), 
         const: false, 
         noexcept: true do
      ret id(:self).member(:data)[id(:index)]
    end
    
    def_ :at, 
         params: [[:i32, :index]], 
         ret: t.ref(:T, const: true), 
         const: true, 
         noexcept: true do
      ret id(:self).member(:data)[id(:index)]
    end
    
    def_ :size, 
         ret: t.i32, 
         const: true, 
         noexcept: true do
      ret id(:self).member(:size)
    end
    
    def_ :empty, 
         ret: t.bool, 
         const: true, 
         noexcept: true do
      ret id(:self).member(:size) == int(0)
    end
  end
end

puts ast.to_node.to_source
puts

# Example 5: Enum class
puts "=== Example 5: Enum Class ==="
ast = program do
  enum_class :Color, t.uint8 do
    enumerator :Red, value: int(1)
    enumerator :Green, value: int(2)
    enumerator :Blue, value: int(3)
  end
  
  # Class using enum
  class_ :ColoredPoint do
    field :point, t.Point
    field :color, t.Color, default: call(:Color, :Red)
    
    # Constructor
    ctor params: [[t.ref(:Point, const: true), :point], [t.Color, :color]], 
         constexpr: true, 
         noexcept: true do
      id(:self).member(:point) = id(:point)
      id(:self).member(:color) = id(:color)
    end
    
    # Member functions
    def_ :get_point, 
         ret: t.ref(:Point, const: true), 
         const: true, 
         noexcept: true do
      ret id(:self).member(:point)
    end
    
    def_ :get_color, 
         ret: t.Color, 
         const: true, 
         noexcept: true do
      ret id(:self).member(:color)
    end
    
    def_ :set_color, 
         params: [[t.Color, :color]], 
         ret: t.void, 
         noexcept: true do
      id(:self).member(:color) = id(:color)
    end
  end
end

puts ast.to_node.to_source
puts

puts "=== Features demonstrated ==="
puts "✅ Rule of Five generation"
puts "✅ Abstract base classes with pure virtual functions"
puts "✅ Derived classes with override"
puts "✅ Template classes with proper instantiation"
puts "✅ Enum classes with underlying types"
puts "✅ Access specifiers (public, private, protected)"
puts "✅ Virtual functions and polymorphism"
puts "✅ Const correctness"
puts "✅ Exception safety (noexcept)"
puts

puts "Demo completed successfully! 🎉"
