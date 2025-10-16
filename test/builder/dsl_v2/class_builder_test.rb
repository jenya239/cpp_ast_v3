#!/usr/bin/env ruby
# frozen_string_literal: true

require "test/unit"
require_relative "../../../lib/cpp_ast"
require_relative "../../../lib/cpp_ast/builder/dsl_v2_simple"

class ClassBuilderTest < Test::Unit::TestCase
  include CppAst::Builder::DSLv2Improved

  def test_basic_class
    # Test basic class creation
    class_builder = class_ :Point do
      field :x, t.f32, default: float(0.0)
      field :y, t.f32, default: float(0.0)
    end
    
    assert_not_nil class_builder
    assert_equal :Point, class_builder.name
    assert_equal 2, class_builder.members.size
  end

  def test_class_with_constructor
    # Test class with constructor
    class_builder = class_ :Point do
      field :x, t.f32
      field :y, t.f32
      
      ctor params: [[:f32, :x], [:f32, :y]], 
           constexpr: true, 
           noexcept: true do
          id(:self).member(:x).assign(id(:x))
          id(:self).member(:y).assign(id(:y))
      end
    end
    
    assert_not_nil class_builder
    assert_equal 3, class_builder.members.size  # 2 fields + 1 constructor
  end

  def test_class_with_destructor
    # Test class with destructor
    class_builder = class_ :Resource do
      field :ptr, t.raw_ptr(t.byte)
      
      dtor noexcept: true do
        delete id(:ptr)
      end
    end
    
    assert_not_nil class_builder
    assert_equal 2, class_builder.members.size  # 1 field + 1 destructor
  end

  def test_class_with_methods
    # Test class with methods
    class_builder = class_ :Point do
      field :x, t.f32
      field :y, t.f32
      
      def_ :length, 
           ret: t.f32, 
           const: true, 
           noexcept: true do
        ret (id(:x) * id(:x) + id(:y) * id(:y)).call(:sqrt)
      end
      
      def_ :move, 
           params: [[:f32, :dx], [:f32, :dy]], 
           ret: t.void, 
           noexcept: true do
          id(:self).member(:x).assign(id(:self).member(:x) + id(:dx))
          id(:self).member(:y).assign(id(:self).member(:y) + id(:dy))
      end
    end
    
    assert_not_nil class_builder
    assert_equal 4, class_builder.members.size  # 2 fields + 2 methods
  end

  def test_class_with_inheritance
    # Test class with inheritance
    class_builder = class_ :Circle do
      inherits :Shape, access: :public
      
      field :radius, t.f32, default: float(0.0)
      
      def_ :area, 
           ret: t.f32, 
           const: true, 
           override: true, 
           noexcept: true do
        ret float(3.14159) * id(:radius) * id(:radius)
      end
    end
    
    assert_not_nil class_builder
    assert_equal 1, class_builder.base_classes.size
    assert_equal :Shape, class_builder.base_classes.first.name
    assert_equal :public, class_builder.base_classes.first.access
  end

  def test_class_with_rule_of_five
    # Test class with rule of five
    class_builder = class_ :Point do
      field :x, t.f32
      field :y, t.f32
      
      rule_of_five!
    end
    
    assert_not_nil class_builder
    # Rule of five should add 5 methods: default ctor, copy ctor, move ctor, copy assign, move assign, dtor
    assert class_builder.members.size >= 5
  end

  def test_class_with_rule_of_zero
    # Test class with rule of zero
    class_builder = class_ :Point do
      field :x, t.f32
      field :y, t.f32
      
      rule_of_zero!
    end
    
    assert_not_nil class_builder
    # Rule of zero should add default implementations
    assert class_builder.members.size >= 5
  end

  def test_class_with_access_specifiers
    # Test class with access specifiers
    class_builder = class_ :Point do
      public_section do
        field :x, t.f32
        field :y, t.f32
        
        def_ :length, ret: t.f32, const: true, noexcept: true do
          ret (id(:x) * id(:x) + id(:y) * id(:y)).call(:sqrt)
        end
      end
      
      private_section do
        field :id, t.i32
        
        def_ :generate_id, ret: t.i32, noexcept: true do
          ret call(:rand)
        end
      end
    end
    
    assert_not_nil class_builder
    assert class_builder.members.size >= 5  # 3 public + 2 private + access specifiers
  end

  def test_abstract_class
    # Test abstract class
    class_builder = class_ :Shape, abstract: true do
      def_ :area, 
           ret: t.f32, 
           const: true, 
           virtual: true, 
           pure_virtual: true do
        # Pure virtual - no implementation
      end
      
      dtor virtual: true, noexcept: true do
        # Virtual destructor
      end
    end
    
    assert_not_nil class_builder
    assert_equal true, class_builder.modifiers[:abstract]
  end

  def test_final_class
    # Test final class
    class_builder = class_ :Point, final: true do
      field :x, t.f32
      field :y, t.f32
    end
    
    assert_not_nil class_builder
    assert_equal true, class_builder.modifiers[:final]
  end

  def test_template_class
    # Test template class
    class_builder = template_class [:T], :Vector do
      field :data, t.span(t.ref(:T, mutable: true))
      field :size, t.i32, default: int(0)
      
      ctor params: [[t.span(t.ref(:T, mutable: true)), :data], [:i32, :size]], 
           constexpr: true, 
           noexcept: true do
          id(:self).member(:data).assign(id(:data))
          id(:self).member(:size).assign(id(:size))
      end
    end
    
    assert_not_nil class_builder
    assert_equal true, class_builder.modifiers[:template]
    assert_equal [:T], class_builder.modifiers[:template_params]
  end

  def test_struct_creation
    # Test struct creation
    struct_builder = struct_ :Point do
      field :x, t.f32
      field :y, t.f32
    end
    
    assert_not_nil struct_builder
    assert_equal :Point, struct_builder.name
  end

  def test_union_creation
    # Test union creation
    union_builder = union_ :Variant do
      field :i, t.i32
      field :f, t.f32
      field :s, t.string
    end
    
    assert_not_nil union_builder
    assert_equal :Variant, union_builder.name
  end

  def test_class_with_static_members
    # Test class with static members
    class_builder = class_ :Math do
      def_ :pi, 
           ret: t.f32, 
           static: true, 
           constexpr: true, 
           noexcept: true do
        ret float(3.14159)
      end
      
      def_ :sqrt, 
           params: [[:f32, :x]], 
           ret: t.f32, 
           static: true, 
           constexpr: true, 
           noexcept: true do
        ret id(:x).call(:sqrt)
      end
    end
    
    assert_not_nil class_builder
    assert_equal 2, class_builder.members.size
  end

  def test_class_with_virtual_methods
    # Test class with virtual methods
    class_builder = class_ :Shape do
      def_ :area, 
           ret: t.f32, 
           const: true, 
           virtual: true, 
           pure_virtual: true do
        # Pure virtual
      end
      
      def_ :perimeter, 
           ret: t.f32, 
           const: true, 
           virtual: true, 
           pure_virtual: true do
        # Pure virtual
      end
      
      dtor virtual: true, noexcept: true do
        # Virtual destructor
      end
    end
    
    assert_not_nil class_builder
    assert_equal 3, class_builder.members.size
  end

  def test_class_with_override_methods
    # Test class with override methods
    class_builder = class_ :Circle do
      inherits :Shape, access: :public
      
      field :radius, t.f32
      
      def_ :area, 
           ret: t.f32, 
           const: true, 
           override: true, 
           noexcept: true do
        ret float(3.14159) * id(:radius) * id(:radius)
      end
      
      def_ :perimeter, 
           ret: t.f32, 
           const: true, 
           override: true, 
           noexcept: true do
        ret float(2.0) * float(3.14159) * id(:radius)
      end
    end
    
    assert_not_nil class_builder
    assert_equal 3, class_builder.members.size  # 1 field + 2 methods
  end

  def test_class_with_final_methods
    # Test class with final methods
    class_builder = class_ :Circle do
      def_ :area, 
           ret: t.f32, 
           const: true, 
           final: true, 
           noexcept: true do
        ret float(3.14159) * id(:radius) * id(:radius)
      end
    end
    
    assert_not_nil class_builder
    assert_equal 1, class_builder.members.size
  end

  def test_class_to_node_conversion
    # Test conversion to AST node
    class_builder = class_ :Point do
      field :x, t.f32
      field :y, t.f32
      
      ctor params: [[:f32, :x], [:f32, :y]], 
           constexpr: true, 
           noexcept: true do
          id(:self).member(:x).assign(id(:x))
          id(:self).member(:y).assign(id(:y))
      end
    end
    
    node = class_builder.to_node
    
    assert_kind_of CppAst::Nodes::ClassDeclaration, node
    assert_equal "Point", node.name
    assert_equal 3, node.members.size  # 2 fields + 1 constructor
  end

  def test_class_with_complex_inheritance
    # Test class with complex inheritance
    class_builder = class_ :Circle do
      inherits :Shape, access: :public
      inherits :Drawable, access: :private
      
      field :radius, t.f32
      field :color, t.string
      
      def_ :draw, 
           params: [[t.ref(:Canvas, mutable: true), :canvas]], 
           ret: t.void, 
           override: true, 
           noexcept: true do
        call(:draw_circle, id(:canvas), id(:radius), id(:color))
      end
    end
    
    assert_not_nil class_builder
    assert_equal 2, class_builder.base_classes.size
    assert_equal 3, class_builder.members.size  # 2 fields + 1 method
  end

  def test_class_with_nested_types
    # Test class with nested types
    class_builder = class_ :Container do
      field :data, t.vec(t.i32)
      field :size, t.i32
      
      # Nested iterator class
      class_ :Iterator do
        field :ptr, t.raw_ptr(t.i32)
        field :end, t.raw_ptr(t.i32)
        
          def_ :operator_not_equal, 
               params: [[t.ref(:Iterator, const: true), :other]], 
               ret: t.bool, 
               const: true, 
               noexcept: true do
            ret id(:ptr) != id(:other).member(:ptr)
          end
      end
    end
    
    assert_not_nil class_builder
    assert_equal 2, class_builder.members.size  # 2 fields
  end

  def test_class_with_friends
    # Test class with friends
    class_builder = class_ :Point do
      field :x, t.f32
      field :y, t.f32
      
        friend_ fn(:distance, 
                   params: [[t.ref(:Point, const: true), :p1], [t.ref(:Point, const: true), :p2]], 
                   ret: t.f32,
                   constexpr: true, 
                   noexcept: true) do
          let_ :dx, id(:p1).member(:x) - id(:p2).member(:x)
          let_ :dy, id(:p1).member(:y) - id(:p2).member(:y)
          ret (id(:dx) * id(:dx) + id(:dy) * id(:dy)).call(:sqrt)
        end
    end
    
    assert_not_nil class_builder
    assert_equal 3, class_builder.members.size  # 2 fields + 1 friend
  end

  def test_class_builder_fluent_api
    # Test fluent API for class builder
    class_builder = class_ :Point
    class_builder.field(:x, t.f32)
    class_builder.field(:y, t.f32)
    class_builder.rule_of_five!
    
    assert_not_nil class_builder
    # rule_of_five! adds 6 methods (default ctor, copy ctor, move ctor, copy assign, move assign, dtor)
    # plus 2 fields = 8 total members
    assert_equal 8, class_builder.members.size
  end
end
