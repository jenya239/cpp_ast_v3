# frozen_string_literal: true

module CppAst
  module Builder
    module TypesDSL
      # Type builder with symbolic API
      class TypeBuilder
        attr_reader :name, :template_args

        def initialize(name, const: false, ref: false, mutable: false, template_args: [])
          # Normalize common type aliases to canonical names
          @name = normalize_type_name(name)
          @const = const
          @ref = ref
          @mutable = mutable
          @template_args = template_args
        end

        private

        def normalize_type_name(name)
          case name
          when :i32 then :int
          when :f32 then :float
          when :f64 then :double
          else name
          end
        end

        public

        # Boolean attribute getters (return the actual boolean values)
        def is_const; @const; end
        def is_ref; @ref; end
        def is_mutable; @mutable; end

        # Chainable builder methods (return new TypeBuilder)
        # These are the primary interface for building types
        def const
          TypeBuilder.new(@name, const: true, ref: @ref, mutable: @mutable, template_args: @template_args)
        end

        def ref(const: true, mutable: @mutable)
          TypeBuilder.new(@name, const: const, ref: true, mutable: mutable, template_args: @template_args)
        end

        # Create mutable reference
        def mut
          TypeBuilder.new(@name, const: false, ref: true, mutable: true, template_args: @template_args)
        end

        # Add template arguments
        def [](*args)
          # Convert symbols to TypeBuilder instances
          converted_args = args.map do |arg|
            if arg.is_a?(Symbol)
              TypeBuilder.new(arg)
            else
              arg
            end
          end
          TypeBuilder.new(@name, const: @const, ref: @ref, mutable: @mutable, template_args: converted_args)
        end

        # Equality comparison
        def ==(other)
          return false unless other.is_a?(TypeBuilder)
          @name == other.name && @const == other.is_const && @ref == other.is_ref &&
          @mutable == other.is_mutable && @template_args == other.template_args
        end
        
        # Convert to C++ type string
        def to_cpp_type
          result = @name.to_s
          
          # Handle standard library types
          case @name
          when :string
            result = "std::string"
          when :vector
            result = "std::vector"
          when :array
            result = "std::array"
          when :unique_ptr
            result = "std::unique_ptr"
          when :shared_ptr
            result = "std::shared_ptr"
          when :weak_ptr
            result = "std::weak_ptr"
          when :raw_ptr
            result = "#{@template_args[0].to_cpp_type}*"
          when :const_raw_ptr
            result = "const #{@template_args[0].to_cpp_type}*"
          when :int, :i32
            result = "int"
          when :float, :f32
            result = "float"
          when :double, :f64
            result = "double"
          when :bool
            result = "bool"
          when :char
            result = "char"
          when :void
            result = "void"
          end
          
          # Add template arguments
          if @template_args.any? && ![:raw_ptr, :const_raw_ptr].include?(@name)
            args = @template_args.map(&:to_cpp_type).join(", ")
            result += "<#{args}>"
          end

          # Add const
          result = "const #{result}" if @const

          # Add reference
          result += "&" if @ref

          result
        end

        # Convert to CppAst node
        def to_ast_node
          Nodes::TypeReference.new(
            name: to_cpp_type,
            is_const: @const,
            is_reference: @ref,
            is_mutable: @mutable
          )
        end
      end
      
      # Type system DSL methods
      class Types
        # Basic types
        def i32; @i32 ||= TypeBuilder.new(:int) end
        def i64; TypeBuilder.new(:long) end
        def f32; @f32 ||= TypeBuilder.new(:float) end
        def f64; TypeBuilder.new(:double) end
        def bool; TypeBuilder.new(:bool) end
        def char; TypeBuilder.new(:char) end
        def string; @string ||= TypeBuilder.new(:string) end
        def byte; TypeBuilder.new(:byte) end
        
        # Integer types
        def int8; TypeBuilder.new(:int8_t) end
        def int16; TypeBuilder.new(:int16_t) end
        def int32; TypeBuilder.new(:int32_t) end
        def int64; TypeBuilder.new(:int64_t) end
        def uint8; TypeBuilder.new(:uint8_t) end
        def uint16; TypeBuilder.new(:uint16_t) end
        def uint32; TypeBuilder.new(:uint32_t) end
        def uint64; TypeBuilder.new(:uint64_t) end
        
        # Float types
        def float32; TypeBuilder.new(:float) end
        def float64; TypeBuilder.new(:double) end
        
        # Character types
        def wchar; TypeBuilder.new(:wchar_t) end
        def char16; TypeBuilder.new(:char16_t) end
        def char32; TypeBuilder.new(:char32_t) end
        
        # String types
        def wstring; TypeBuilder.new(:wstring) end
        def u16string; TypeBuilder.new(:u16string) end
        def u32string; TypeBuilder.new(:u32string) end
        
        # System types
        def size_t
          require_relative "ownership_dsl"
          OwnershipDSL::OwnershipTypeBuilder.new(nil, :size_t)
        end
        def ptrdiff_t
          require_relative "ownership_dsl"
          OwnershipDSL::OwnershipTypeBuilder.new(nil, :ptrdiff_t)
        end
        def null
          require_relative "ownership_dsl"
          OwnershipDSL::OwnershipTypeBuilder.new(nil, :null)
        end
        def auto
          require_relative "ownership_dsl"
          OwnershipDSL::OwnershipTypeBuilder.new(nil, :auto)
        end
        def void
          require_relative "ownership_dsl"
          OwnershipDSL::OwnershipTypeBuilder.new(nil, :void)
        end
        
        # Reference types
        def ref(type, const: false, mutable: false)
          raise ArgumentError, "Type cannot be nil" if type.nil?
          if type.is_a?(Symbol)
            type = TypeBuilder.new(type)
          end
          type.ref(const: const, mutable: mutable)
        end
        
        def mut(type)
          if type.is_a?(Symbol)
            type = TypeBuilder.new(type)
          end
          type.mut
        end
        
        # Ownership types
        def owned(type)
          raise ArgumentError, "Type cannot be nil" if type.nil?
          require_relative "ownership_dsl"
          if type.is_a?(Symbol)
            type = TypeBuilder.new(type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new(type, :owned)
        end

        def shared(type)
          raise ArgumentError, "Type cannot be nil" if type.nil?
          require_relative "ownership_dsl"
          if type.is_a?(Symbol)
            type = TypeBuilder.new(type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new(type, :shared)
        end

        def weak(type)
          raise ArgumentError, "Type cannot be nil" if type.nil?
          require_relative "ownership_dsl"
          if type.is_a?(Symbol)
            type = TypeBuilder.new(type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new(type, :weak)
        end

        def borrowed(type, const: true)
          raise ArgumentError, "Type cannot be nil" if type.nil?
          require_relative "ownership_dsl"
          if type.is_a?(Symbol)
            type = TypeBuilder.new(type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new(type, const ? :borrowed : :mut_borrowed)
        end

        def mut_borrowed(type)
          raise ArgumentError, "Type cannot be nil" if type.nil?
          require_relative "ownership_dsl"
          if type.is_a?(Symbol)
            type = TypeBuilder.new(type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new(type, :mut_borrowed)
        end
        
        # Pointer types
        def raw_ptr(type)
          raise ArgumentError, "Type cannot be nil" if type.nil?
          require_relative "ownership_dsl"
          if type.is_a?(Symbol)
            type = TypeBuilder.new(type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new(type, :raw_ptr)
        end

        def const_raw_ptr(type)
          raise ArgumentError, "Type cannot be nil" if type.nil?
          require_relative "ownership_dsl"
          if type.is_a?(Symbol)
            type = TypeBuilder.new(type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new(type, :const_raw_ptr)
        end

        # Container types
        def vec(inner_type)
          raise ArgumentError, "Type cannot be nil" if inner_type.nil?
          if inner_type.is_a?(Symbol)
            inner_type = TypeBuilder.new(inner_type)
          end
          TypeBuilder.new(:vector, template_args: [inner_type])
        end

        def span(inner_type)
          raise ArgumentError, "Type cannot be nil" if inner_type.nil?
          require_relative "ownership_dsl"
          if inner_type.is_a?(Symbol)
            inner_type = TypeBuilder.new(inner_type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new(inner_type, :span)
        end

        def span_const(inner_type)
          raise ArgumentError, "Type cannot be nil" if inner_type.nil?
          require_relative "ownership_dsl"
          if inner_type.is_a?(Symbol)
            inner_type = TypeBuilder.new(inner_type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new(inner_type, :span_const)
        end
        
        def array(inner_type, size = nil)
          require_relative "ownership_dsl"
          if inner_type.is_a?(Symbol)
            inner_type = TypeBuilder.new(inner_type)
          end
          if size
            OwnershipDSL::OwnershipTypeBuilder.new([inner_type, size], :array)
          else
            OwnershipDSL::OwnershipTypeBuilder.new(inner_type, :array)
          end
        end
        
        # Result/Option types
        def result(ok_type, err_type)
          raise ArgumentError, "Types cannot be nil" if ok_type.nil? || err_type.nil?
          require_relative "ownership_dsl"
          if ok_type.is_a?(Symbol)
            ok_type = TypeBuilder.new(ok_type)
          end
          if err_type.is_a?(Symbol)
            err_type = TypeBuilder.new(err_type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new([ok_type, err_type], :result)
        end

        def option(inner_type)
          raise ArgumentError, "Type cannot be nil" if inner_type.nil?
          require_relative "ownership_dsl"
          if inner_type.is_a?(Symbol)
            inner_type = TypeBuilder.new(inner_type)
          end
          OwnershipDSL::OwnershipTypeBuilder.new(inner_type, :option)
        end

        # Variant and Tuple types
        def variant(*types)
          raise ArgumentError, "Types cannot be empty" if types.empty?
          require_relative "ownership_dsl"
          types = types.map do |type|
            if type.is_a?(Symbol)
              TypeBuilder.new(type)
            else
              type
            end
          end
          OwnershipDSL::OwnershipTypeBuilder.new(types, :variant)
        end

        def tuple(*types)
          raise ArgumentError, "Types cannot be empty" if types.empty?
          require_relative "ownership_dsl"
          types = types.map do |type|
            if type.is_a?(Symbol)
              TypeBuilder.new(type)
            else
              type
            end
          end
          OwnershipDSL::OwnershipTypeBuilder.new(types, :tuple)
        end

        # Function type
        def function(return_type, *param_types)
          raise ArgumentError, "Return type cannot be nil" if return_type.nil?
          require_relative "ownership_dsl"
          if return_type.is_a?(Symbol)
            return_type = TypeBuilder.new(return_type)
          end
          param_types = param_types.map do |type|
            if type.is_a?(Symbol)
              TypeBuilder.new(type)
            else
              type
            end
          end
          OwnershipDSL::OwnershipTypeBuilder.new([return_type, *param_types], :function)
        end
        
        # Lambda type
        def lambda(*param_types)
          require_relative "ownership_dsl"
          if param_types.empty?
            OwnershipDSL::OwnershipTypeBuilder.new(nil, :lambda)
          else
            lambda_type(*param_types)
          end
        end

        def lambda_type(*param_types)
          require_relative "ownership_dsl"
          OwnershipDSL::OwnershipTypeBuilder.new(param_types, :lambda)
        end
        
        # Custom type
        def of(type_name)
          require_relative "ownership_dsl"
          OwnershipDSL::OwnershipTypeBuilder.new(type_name, :custom)
        end
        
        # Template type
        def template(name, *params)
          params = params.map do |param|
            if param.is_a?(Symbol)
              TypeBuilder.new(param)
            else
              param
            end
          end
          TypeBuilder.new(name, template_args: params)
        end

        # Custom types
        def Circle; TypeBuilder.new(:Circle) end
        def Rectangle; TypeBuilder.new(:Rectangle) end
        def Rect; TypeBuilder.new(:Rect) end
        def Triangle; TypeBuilder.new(:Triangle) end
        def Point; TypeBuilder.new(:Point) end
        
        # lambda method already defined above
      end
      
      # Include Types module in DSL
      def self.included(base)
        base.include Types
      end
    end
  end
end
