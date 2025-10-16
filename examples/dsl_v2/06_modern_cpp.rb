#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/cpp_ast"
require_relative "../../lib/cpp_ast/builder/dsl_v2"

include CppAst::Builder::DSLv2

puts "=== DSL v2: Modern C++ Features ==="
puts "Demonstrating C++20/23 features through DSL"
puts

# Example 1: Concepts
puts "=== Example 1: Concepts ==="
ast = program do
  # Sortable concept
  concept_ :Sortable, [:T] do
    requires_ do
      fn :less, params: [[t.ref(:T, const: true), :a], [t.ref(:T, const: true), :b]], ret: t.bool
    end
  end
  
  # Comparable concept
  concept_ :Comparable, [:T] do
    requires_ do
      fn :operator<, params: [[t.ref(:T, const: true), :a], [t.ref(:T, const: true), :b]], ret: t.bool
    end
  end
  
  # Sort function with concepts
  template_ [:T] do
    fn :sort, 
       params: [[t.span(t.ref(:T, mutable: true)), :arr]], 
       ret: t.void,
       requires: concept(:Sortable, :T),
       noexcept: true do
      # Simple bubble sort
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

# Example 2: Modules (C++20)
puts "=== Example 2: Modules (C++20) ==="
ast = program do
  # Module declaration
  module_ "app.geom" do
    export_ do
      # Vec2 struct
      struct_ :Vec2 do
        field :x, t.f32
        field :y, t.f32
        
        ctor params: [[:f32, :x], [:f32, :y]], constexpr: true, noexcept: true do
          id(:self).member(:x) = id(:x)
          id(:self).member(:y) = id(:y)
        end
        
        rule_of_five!
      end
      
      # length function
      fn :length, 
         params: [[t.ref(:Vec2, const: true), :v]], 
         ret: t.f32,
         constexpr: true, 
         noexcept: true do
        ret (id(:v).member(:x) * id(:v).member(:x) + 
             id(:v).member(:y) * id(:v).member(:y)).call(:sqrt)
      end
      
      # scale function
      fn :scale, 
         params: [[t.ref(:Vec2, const: true), :v], [:f32, :k]], 
         ret: t.Vec2,
         constexpr: true, 
         noexcept: true do
        ret call(:Vec2, 
                 id(:v).member(:x) * id(:k), 
                 id(:v).member(:y) * id(:k))
      end
    end
  end
  
  # Import module
  import_ "app.geom"
end

puts ast.to_node.to_source
puts

# Example 3: Coroutines
puts "=== Example 3: Coroutines ==="
ast = program do
  # Task type
  type_alias :Task, t.template(:std, :task)
  
  # Async function
  async_fn :fetch_data, 
           params: [[t.string, :url]], 
           ret: t.Task(t.string) do
    let_ :data, co_await(call(:http_get, id(:url)))
    co_return id(:data)
  end
  
  # Async function with error handling
  async_fn :safe_fetch, 
           params: [[t.string, :url]], 
           ret: t.Task(t.result(t.string, t.string)) do
    try_ do
      let_ :data, co_await(call(:http_get, id(:url)))
      co_return ok(id(:data))
    catch t.string, :error do
      co_return err(id(:error))
    end
  end
  
  # Generator function
  async_fn :fibonacci, 
           params: [[:i32, :n]], 
           ret: t.Task(t.i32) do
    let_ :a, int(0)
    let_ :b, int(1)
    for_ id(:i), int(0), id(:n), id(:i)++ do
      co_yield id(:a)
      let_ :temp, id(:a)
      id(:a) = id(:b)
      id(:b) = id(:temp) + id(:b)
    end
    co_return id(:a)
  end
end

puts ast.to_node.to_source
puts

# Example 4: Ranges and Algorithms
puts "=== Example 4: Ranges and Algorithms ==="
ast = program do
  namespace :std do
    namespace :ranges do
      # Transform algorithm
      fn :transform, 
         params: [[t.span(t.ref(:T, mutable: true)), :range], [t.function(t.T, t.T), :func]], 
         ret: t.void,
         noexcept: true do
        for_range :it, id(:range) do
          deref(id(:it)) = id(:func).call(deref(id(:it)))
        end
      end
      
      # Filter algorithm
      fn :filter, 
         params: [[t.span(t.ref(:T, mutable: true)), :range], [t.function(t.T, t.bool), :pred]], 
         ret: t.void,
         noexcept: true do
        let_ :write_it, id(:range).call(:begin)
        for_range :it, id(:range) do
          if_ id(:pred).call(deref(id(:it))) do
            deref(id(:write_it)) = deref(id(:it))
            id(:write_it) = id(:write_it) + int(1)
          end
        end
      end
      
      # Reduce algorithm
      fn :reduce, 
         params: [[t.span(t.ref(:T, const: true)), :range], [t.T, :init], [t.function(t.T, t.T, t.T), :op]], 
         ret: t.T,
         noexcept: true do
        let_ :result, id(:init)
        for_range :it, id(:range) do
          id(:result) = id(:op).call(id(:result), deref(id(:it)))
        end
        ret id(:result)
      end
    end
  end
end

puts ast.to_node.to_source
puts

# Example 5: Metaprogramming
puts "=== Example 5: Metaprogramming ==="
ast = program do
  # Type traits
  template_ [:T] do
    fn :is_pointer, 
       params: [], 
       ret: t.bool,
       constexpr: true, 
       noexcept: true do
      ret call(:std, :is_pointer, t.T)
    end
  end
  
  # SFINAE example
  template_ [:T] do
    fn :enable_if_pointer, 
       params: [[t.ref(:T, const: true), :ptr]], 
       ret: t.void,
       requires: concept(:std, :is_pointer, :T),
       noexcept: true do
      deref(id(:ptr)) = deref(id(:ptr)) + int(1)
    end
  end
  
  # Variadic template
  template_ [:Ts] do
    fn :make_tuple, 
       params: [[t.ref(:Ts, const: true), :args]], 
       ret: t.tuple(t.Ts),
       constexpr: true, 
       noexcept: true do
      ret call(:std, :make_tuple, id(:args))
    end
  end
  
  # Perfect forwarding
  template_ [:T] do
    fn :forward, 
       params: [[t.ref(:T, mutable: true), :arg]], 
       ret: t.ref(:T, mutable: true),
       constexpr: true, 
       noexcept: true do
      ret call(:std, :forward, id(:arg))
    end
  end
end

puts ast.to_node.to_source
puts

# Example 6: Memory Management
puts "=== Example 6: Memory Management ==="
ast = program do
  # Custom allocator
  class_ :PoolAllocator do
    field :pool, t.span(t.byte)
    field :used, t.i32, default: int(0)
    
    ctor params: [[:i32, :size]], noexcept: true do
      id(:self).member(:pool) = call(:std, :make_unique, t.byte, id(:size))
      id(:self).member(:used) = int(0)
    end
    
    def_ :allocate, 
         params: [[:i32, :size]], 
         ret: t.raw_ptr(t.byte),
         noexcept: true do
      if_ id(:self).member(:used) + id(:size) <= id(:self).member(:pool).call(:size) do
        let_ :ptr, id(:self).member(:pool).call(:data) + id(:self).member(:used)
        id(:self).member(:used) = id(:self).member(:used) + id(:size)
        ret id(:ptr)
      else_
        ret nullptr
      end
    end
    
    def_ :deallocate, 
         params: [[t.raw_ptr(t.byte), :ptr], [:i32, :size]], 
         ret: t.void,
         noexcept: true do
      # Pool allocator doesn't deallocate individual blocks
    end
    
    dtor noexcept: true do
      # Pool is automatically deallocated
    end
  end
  
  # RAII wrapper
  class_ :PooledResource do
    field :allocator, t.ref(:PoolAllocator, mutable: true)
    field :ptr, t.raw_ptr(t.byte)
    field :size, t.i32
    
    ctor params: [[t.ref(:PoolAllocator, mutable: true), :allocator], [:i32, :size]], 
         noexcept: true do
      id(:self).member(:allocator) = id(:allocator)
      id(:self).member(:size) = id(:size)
      id(:self).member(:ptr) = id(:allocator).call(:allocate, id(:size))
    end
    
    # Move constructor
    ctor params: [[t.ref(:PooledResource, mutable: true), :other]], 
         noexcept: true do
      id(:self).member(:allocator) = id(:other).member(:allocator)
      id(:self).member(:ptr) = id(:other).member(:ptr)
      id(:self).member(:size) = id(:other).member(:size)
      id(:other).member(:ptr) = nullptr
    end
    
    # Move assignment
    def_ :operator=, 
         params: [[t.ref(:PooledResource, mutable: true), :other]], 
         ret: t.ref(:PooledResource),
         noexcept: true do
      if_ id(:self) != id(:other) do
        id(:self).member(:allocator) = id(:other).member(:allocator)
        id(:self).member(:ptr) = id(:other).member(:ptr)
        id(:self).member(:size) = id(:other).member(:size)
        id(:other).member(:ptr) = nullptr
      end
      ret id(:self)
    end
    
    def_ :get, 
         ret: t.raw_ptr(t.byte), 
         const: true, 
         noexcept: true do
      ret id(:self).member(:ptr)
    end
    
    def_ :is_valid, 
         ret: t.bool, 
         const: true, 
         noexcept: true do
      ret id(:self).member(:ptr) != nullptr
    end
    
    dtor noexcept: true do
      if_ id(:self).member(:ptr) != nullptr do
        id(:self).member(:allocator).call(:deallocate, id(:self).member(:ptr), id(:self).member(:size))
      end
    end
  end
end

puts ast.to_node.to_source
puts

puts "=== Features demonstrated ==="
puts "✅ C++20 Concepts with requires clauses"
puts "✅ C++20 Modules with export/import"
puts "✅ C++20 Coroutines (async/await, generators)"
puts "✅ C++20 Ranges and algorithms"
puts "✅ Template metaprogramming and SFINAE"
puts "✅ Custom allocators and memory management"
puts "✅ RAII with proper resource management"
puts "✅ Perfect forwarding and move semantics"
puts "✅ Variadic templates"
puts "✅ Type traits and compile-time programming"
puts

puts "Demo completed successfully! 🎉"
