#!/usr/bin/env ruby
# frozen_string_literal: true

require "test/unit"
require_relative "../../../lib/cpp_ast"
require_relative "../../../lib/cpp_ast/builder/dsl_v2_simple"

class DSLv2IntegrationTest < Test::Unit::TestCase
  include CppAst::Builder::DSLv2Improved

  def test_complete_program_generation
    # Test complete program generation
    program_ast = program do
      # Include headers
      include_ "iostream"
      include_ "vector", system: true
      include_ "memory", system: true
      
      # Using declarations
      using_ :std, :cout, :endl
      using_namespace :std
      
      # Type alias
      type_alias :Point, t.tuple(t.f32, t.f32)
      
      # Enum
      enum_ :Color do
        enumerator :Red, value: int(0)
        enumerator :Green, value: int(1)
        enumerator :Blue, value: int(2)
      end
      
      # Template function
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
      
      # Main function
      fn :main, 
         params: [[:i32, :argc], [t.raw_ptr(t.raw_ptr(t.char)), :argv]], 
         ret: t.i32 do
        let_ :x, int(42)
        let_ :y, int(24)
        let_ :result, call(:max, id(:x), id(:y))
        
        call(:cout) << string("Max: ") << id(:result) << call(:endl)
        ret int(0)
      end
    end
    
    assert_not_nil program_ast
    assert_kind_of CppAst::Builder::DSLv2Improved::ProgramBuilder, program_ast
    assert program_ast.statements.size > 0
  end

  def test_namespace_generation
    # Test namespace generation
    namespace_ast = namespace :app do
      namespace :geom do
        # Vec2 struct
        struct_ :Vec2 do
          field :x, t.f32
          field :y, t.f32
          
          ctor params: [[:f32, :x], [:f32, :y]], 
               constexpr: true, 
               noexcept: true do
        id(:self).member(:x).assign(id(:x))
        id(:self).member(:y).assign(id(:y))
          end
          
          rule_of_five!
          
          def_ :length, 
               ret: t.f32, 
               const: true, 
               noexcept: true do
            ret (id(:x) * id(:x) + id(:y) * id(:y)).call(:sqrt)
          end
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
      end
    end
    
    assert_not_nil namespace_ast
    assert_kind_of CppAst::Nodes::NamespaceDeclaration, namespace_ast
    assert_equal "app", namespace_ast.name
  end

  def test_class_with_ownership_types
    # Test class with ownership types
    class_ast = class_ :ResourceManager do
      field :resource, t.owned(:Resource)
      field :is_valid, t.bool, default: bool(false)
      
      ctor params: [[:i32, :size]], 
           noexcept: true do
          id(:self).member(:resource).assign(new(t.Resource, id(:size)))
          id(:self).member(:is_valid).assign(bool(true))
      end
      
      ctor params: [[t.ref(:ResourceManager, mutable: true), :other]], 
           noexcept: true do
        id(:self).member(:resource).assign(id(:other).member(:resource))
        id(:self).member(:is_valid).assign(id(:other).member(:is_valid))
        id(:other).member(:resource).assign(nullptr)
        id(:other).member(:is_valid).assign(bool(false))
      end
      
      def_ :operator=, 
           params: [[t.ref(:ResourceManager, mutable: true), :other]], 
           ret: t.ref(:ResourceManager),
           noexcept: true do
        if_ id(:self) != id(:other) do
          if_ id(:self).member(:is_valid) do
            delete id(:self).member(:resource)
          end
            id(:self).member(:resource).assign(id(:other).member(:resource))
            id(:self).member(:is_valid).assign(id(:other).member(:is_valid))
            id(:other).member(:resource).assign(nullptr)
            id(:other).member(:is_valid).assign(bool(false))
        end
        ret id(:self)
      end
      
      dtor noexcept: true do
        if_ id(:self).member(:is_valid) do
          delete id(:self).member(:resource)
        end
      end
      
      def_ :is_valid, 
           ret: t.bool, 
           const: true, 
           noexcept: true do
        ret id(:self).member(:is_valid)
      end
    end
    
    assert_not_nil class_ast
    assert_kind_of CppAst::Builder::ClassBuilder::ClassBuilder, class_ast
    assert_equal :ResourceManager, class_ast.name
  end

  def test_function_with_result_types
    # Test function with Result types
    function_ast = fn :safe_divide, 
                      params: [[:f32, :a], [:f32, :b]], 
                      ret: t.result(t.f32, t.string),
                      noexcept: true do
      if_ id(:b) == float(0.0) do
        ret err(string("Division by zero"))
      else_
        ret ok(id(:a) / id(:b))
      end
    end
    
    assert_not_nil function_ast
    assert_kind_of CppAst::Builder::FunctionBuilder::FunctionBuilder, function_ast
    assert_equal :safe_divide, function_ast.name
    assert_equal t.result(t.f32, t.string), function_ast.ret_type
  end

  def test_control_flow_integration
    # Test control flow integration
    control_ast = fn :process_array, 
                     params: [[t.span(t.f32), :data]], 
                     ret: t.f32,
                     noexcept: true do
      let_ :sum, float(0.0)
      let_ :count, int(0)
      
      for_range :it, id(:data) do
        if_ deref(id(:it)) > float(0.0) do
            id(:sum).assign(id(:sum) + deref(id(:it)))
            id(:count).assign(id(:count) + int(1))
        end
      end
      
      if_ id(:count) > int(0) do
        ret id(:sum) / cast(t.f32, id(:count))
      else_
        ret float(0.0)
      end
    end
    
    assert_not_nil control_ast
    assert_kind_of CppAst::Builder::FunctionBuilder::FunctionBuilder, control_ast
    assert_equal :process_array, control_ast.name
  end

  def test_template_class_integration
    # Test template class integration
    template_class_ast = template_class [:T], :Vector do
      field :data, t.span(t.ref(:T, mutable: true))
      field :size, t.i32, default: int(0)
      
      ctor params: [[t.span(t.ref(:T, mutable: true)), :data], [:i32, :size]], 
           constexpr: true, 
           noexcept: true do
          id(:self).member(:data).assign(id(:data))
          id(:self).member(:size).assign(id(:size))
      end
      
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
    end
    
    assert_not_nil template_class_ast
    assert_kind_of CppAst::Builder::ClassBuilder::ClassBuilder, template_class_ast
    assert_equal :Vector, template_class_ast.name
    assert_equal true, template_class_ast.modifiers[:template]
    assert_equal [:T], template_class_ast.modifiers[:template_params]
  end

  def test_modern_cpp_features
    # Test modern C++ features
    modern_ast = program do
      # Concept
      concept_ :Sortable, [:T] do
        requires_ do
          fn :less, params: [[t.ref(:T, const: true), :a], [t.ref(:T, const: true), :b]], ret: t.bool
        end
      end
      
      # Template function with concept
      template_ [:T] do
        fn :sort, 
           params: [[t.span(t.ref(:T, mutable: true)), :arr]], 
           ret: t.void,
           requires: concept(:Sortable, :T),
           noexcept: true do
          # Simple bubble sort
            for_ id(:i), int(0), id(:arr).call(:size) - int(1), id(:i).increment do
            for_ id(:j), int(0), id(:arr).call(:size) - id(:i) - int(1), id(:j).increment do
              if_ id(:arr)[id(:j)] > id(:arr)[id(:j) + int(1)] do
                let_ :temp, id(:arr)[id(:j)]
                id(:arr)[id(:j)].assign(id(:arr)[id(:j) + int(1)])
                id(:arr)[id(:j) + int(1)].assign(id(:temp))
              end
            end
          end
        end
      end
      
      # Module (C++20)
      module_ "app.geom" do
        export_ do
          struct_ :Vec2 do
            field :x, t.f32
            field :y, t.f32
          end
          
          fn :length, 
             params: [[t.ref(:Vec2, const: true), :v]], 
             ret: t.f32,
             constexpr: true, 
             noexcept: true do
            ret (id(:v).member(:x) * id(:v).member(:x) + 
                 id(:v).member(:y) * id(:v).member(:y)).call(:sqrt)
          end
        end
      end
    end
    
    assert_not_nil modern_ast
    assert_kind_of CppAst::Builder::DSLv2Improved::ProgramBuilder, modern_ast
    assert modern_ast.statements.size > 0
  end

  def test_aurora_syntax_integration
    # Test Aurora syntax integration
    aurora_ast = program do
      # Aurora-style type definitions
      type_alias :Vec2, t.tuple(t.f32, t.f32)

      # Define the variant component types first as structs
      struct_ :Circle do
        field :r, t.f32
      end

      struct_ :Rect do
        field :w, t.f32
        field :h, t.f32
      end

      struct_ :Polygon do
        field :points, :int  # Simplified - just number of points
      end

      # Now define Shape as variant of these types
      type_alias :Shape, t.variant(:Circle, :Rect, :Polygon)

      # Aurora-style functions
      fn :length,
         params: [[:Vec2, :v]],
         ret: t.f32,
         constexpr: true,
         noexcept: true do
        let_ :x, id(:v).call(:get, int(0))
        let_ :y, id(:v).call(:get, int(1))
        ret (id(:x) * id(:x) + id(:y) * id(:y)).call(:sqrt)
      end

      fn :area,
         params: [[:Shape, :shape]],
         ret: t.f32,
         noexcept: true do
        # Simplified - just return a constant
        # Full pattern matching would require std::visit
        ret float(0.0)
      end
    end

    assert_not_nil aurora_ast
    assert_kind_of CppAst::Builder::DSLv2Improved::ProgramBuilder, aurora_ast
    assert aurora_ast.statements.size > 0
  end

  def test_error_handling_integration
    # Test error handling integration
    error_ast = fn :safe_operation, 
                   params: [[:f32, :x], [:f32, :y]], 
                   ret: t.result(t.f32, t.string),
                   noexcept: true do
        if_ id(:y) == float(0.0) do
          ret err(string("Division by zero"))
        else_
          if_ id(:x) < float(0.0) do
            ret err(string("Negative value"))
          else_
            let_ :result, id(:x) / id(:y)
            if_ id(:result) > float(1000.0) do
              ret err(string("Result too large"))
            else_
              ret ok(id(:result))
            end
          end
        end
    end
    
    assert_not_nil error_ast
    assert_kind_of CppAst::Builder::FunctionBuilder::FunctionBuilder, error_ast
    assert_equal :safe_operation, error_ast.name
    assert_equal t.result(t.f32, t.string), error_ast.ret_type
  end

  def test_performance_optimization
    # Test performance optimization
    perf_ast = fn :optimized_sum, 
                  params: [[t.span(t.f32), :data]], 
                  ret: t.f32,
                  constexpr: true, 
                  noexcept: true do
      let_ :sum, float(0.0)
      let_ :size, id(:data).call(:size)
      
        for_ id(:i), int(0), id(:size), id(:i).increment do
          id(:sum).assign(id(:sum) + id(:data)[id(:i)])
      end
      
      ret id(:sum)
    end
    
    assert_not_nil perf_ast
    assert_kind_of CppAst::Builder::FunctionBuilder::FunctionBuilder, perf_ast
    assert_equal :optimized_sum, perf_ast.name
    assert_equal true, perf_ast.modifiers[:constexpr]
    assert_equal true, perf_ast.modifiers[:noexcept]
  end

  def test_ast_node_conversion
    # Test AST node conversion
    program_ast = program do
      fn :test, 
         params: [[:i32, :x]], 
         ret: t.i32,
         constexpr: true, 
         noexcept: true do
        ret id(:x) * int(2)
      end
    end
    
    node = program_ast.to_node
    assert_kind_of CppAst::Nodes::Program, node
    assert_equal 1, node.statements.size
  end

  def test_source_generation
    # Test source generation
    program_ast = program do
      fn :hello, 
         params: [], 
         ret: t.void do
        call(:printf, string("Hello, World!\n"))
      end
    end
    
    source = program_ast.to_node.to_source
    assert_not_nil source
    assert_kind_of String, source
    assert source.include?("void hello()")
  end
end
