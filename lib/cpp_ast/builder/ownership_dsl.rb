# frozen_string_literal: true

module CppAst
  module Builder
    module OwnershipDSL
      # Ownership type builder
      class OwnershipTypeBuilder
        attr_reader :inner_type, :ownership_kind

        def initialize(inner_type, ownership_kind)
          @inner_type = inner_type
          @ownership_kind = ownership_kind
        end

        # Resolve symbol to C++ type string
        private def resolve_type(type)
          return type.to_cpp_type if type.respond_to?(:to_cpp_type)
          return resolve_symbol(type) if type.is_a?(Symbol)
          type.to_s
        end

        private def resolve_symbol(sym)
          case sym
          when :i32, :int then "int"
          when :i64, :long then "long long"
          when :f32, :float then "float"
          when :f64, :double then "double"
          when :bool then "bool"
          when :char then "char"
          when :void then "void"
          when :string then "std::string"
          when :int8_t, :int8 then "int8_t"
          when :int16_t, :int16 then "int16_t"
          when :int32_t, :int32 then "int32_t"
          when :int64_t, :int64 then "int64_t"
          when :uint8_t, :uint8 then "uint8_t"
          when :uint16_t, :uint16 then "uint16_t"
          when :uint32_t, :uint32 then "uint32_t"
          when :uint64_t, :uint64 then "uint64_t"
          when :size_t then "size_t"
          when :ptrdiff_t then "ptrdiff_t"
          else sym.to_s
          end
        end

        # Convert to C++ type string
        def to_cpp_type
          case @ownership_kind
          when :owned
            "std::unique_ptr<#{resolve_type(@inner_type)}>"
          when :shared
            "std::shared_ptr<#{resolve_type(@inner_type)}>"
          when :weak
            "std::weak_ptr<#{resolve_type(@inner_type)}>"
          when :borrowed
            "const #{resolve_type(@inner_type)}&"
          when :mut_borrowed
            "#{resolve_type(@inner_type)}&"
          when :span
            "std::span<#{resolve_type(@inner_type)}>"
          when :span_const
            "std::span<const #{resolve_type(@inner_type)}>"
          when :raw_ptr
            "#{resolve_type(@inner_type)}*"
          when :const_raw_ptr
            "const #{resolve_type(@inner_type)}*"
          when :result
            ok_type = resolve_type(@inner_type[0])
            err_type = resolve_type(@inner_type[1])
            "std::expected<#{ok_type}, #{err_type}>"
          when :option
            "std::optional<#{resolve_type(@inner_type)}>"
          when :variant
            types = @inner_type.map { |t| resolve_type(t) }.join(', ')
            "std::variant<#{types}>"
          when :tuple
            types = @inner_type.map { |t| resolve_type(t) }.join(', ')
            "std::tuple<#{types}>"
          when :function
            ret_type = resolve_type(@inner_type[0])
            params = @inner_type[1..-1].map { |t| resolve_type(t) }.join(', ')
            "std::function<#{ret_type}(#{params})>"
          when :lambda, :auto
            "auto"
          when :void
            "void"
          when :null
            "nullptr_t"
          when :size_t
            "size_t"
          when :ptrdiff_t
            "ptrdiff_t"
          when :custom
            @inner_type.to_s
          when :string
            "std::string"
          when :wstring
            "wstring"
          when :u16string
            "u16string"
          when :u32string
            "u32string"
          when :char, :wchar, :char16, :char32, :bool
            @ownership_kind.to_s
          when :int8, :int16, :int32, :int64
            "#{@ownership_kind}_t"
          when :uint8, :uint16, :uint32, :uint64
            "#{@ownership_kind}_t"
          when :float32
            "float"
          when :float64
            "double"
          when :array
            if @inner_type.is_a?(Array)
              "std::array<#{resolve_type(@inner_type[0])}, #{@inner_type[1]}>"
            else
              "std::array<#{resolve_type(@inner_type)}>"
            end
          else
            raise ArgumentError, "Unknown ownership kind: #{@ownership_kind}"
          end
        end
        
        # Convert to CppAst node
        def to_ast_node
          Nodes::TypeReference.new(
            name: to_cpp_type,
            is_const: @ownership_kind == :borrowed,
            is_reference: @ownership_kind == :borrowed || @ownership_kind == :mut_borrowed,
            is_mutable: @ownership_kind == :mut_borrowed
          )
        end
        
        # Equality comparison
        def ==(other)
          return false unless other.is_a?(OwnershipTypeBuilder)
          @ownership_kind == other.ownership_kind && @inner_type == other.inner_type
        end
        
        # Add call method for lambda
        def call(*args)
          if @ownership_kind == :lambda
            "auto"
          else
            to_cpp_type
          end
        end
      end
      
      # Ownership DSL methods
      module Ownership
        # Owned type (unique_ptr)
        def owned(type)
          OwnershipTypeBuilder.new(type, :owned)
        end
        
        # Shared ownership (shared_ptr)
        def shared(type)
          OwnershipTypeBuilder.new(type, :shared)
        end
        
        # Weak reference (weak_ptr)
        def weak(type)
          OwnershipTypeBuilder.new(type, :weak)
        end
        
        # Borrowed type (const T&)
        def borrowed(type)
          OwnershipTypeBuilder.new(type, :borrowed)
        end
        
        # Mutable borrowed type (T&)
        def mut_borrowed(type)
          OwnershipTypeBuilder.new(type, :mut_borrowed)
        end
        
        # Span type (std::span<T>)
        def span(type)
          OwnershipTypeBuilder.new(type, :span)
        end
        
        # Const span type (std::span<const T>)
        def span_const(type)
          OwnershipTypeBuilder.new(type, :span_const)
        end
        
        # Raw pointer (T*)
        def raw_ptr(type)
          OwnershipTypeBuilder.new(type, :raw_ptr)
        end
        
        # Const raw pointer (const T*)
        def const_raw_ptr(type)
          OwnershipTypeBuilder.new(type, :const_raw_ptr)
        end
        
        # Array type (T[])
        def array(type, size = nil)
          if size
            OwnershipTypeBuilder.new(type, :array_sized)
          else
            OwnershipTypeBuilder.new(type, :array)
          end
        end
        
        # Result type (std::expected<T, E>)
        def result(ok_type, err_type)
          OwnershipTypeBuilder.new([ok_type, err_type], :result)
        end
        
        # Option type (std::optional<T>)
        def option(type)
          OwnershipTypeBuilder.new(type, :option)
        end
        
        # Variant type (std::variant<Ts...>)
        def variant(*types)
          OwnershipTypeBuilder.new(types, :variant)
        end
        
        # Tuple type (std::tuple<Ts...>)
        def tuple(*types)
          OwnershipTypeBuilder.new(types, :tuple)
        end
        
        # Function type (std::function<R(Args...)>)
        def function(ret_type, *param_types)
          OwnershipTypeBuilder.new([ret_type, *param_types], :function)
        end
        
        # Lambda type (auto)
        def lambda_type
          OwnershipTypeBuilder.new(nil, :lambda)
        end
        
        # Auto type (auto)
        def auto
          OwnershipTypeBuilder.new(nil, :auto)
        end
        
        # Void type (void)
        def void
          OwnershipTypeBuilder.new(nil, :void)
        end
        
        # Null type (nullptr_t)
        def null
          OwnershipTypeBuilder.new(nil, :null)
        end
        
        # Size type (size_t)
        def size_t
          OwnershipTypeBuilder.new(nil, :size_t)
        end
        
        # Index type (ptrdiff_t)
        def ptrdiff_t
          OwnershipTypeBuilder.new(nil, :ptrdiff_t)
        end
        
        # Integer types
        def int8; OwnershipTypeBuilder.new(nil, :int8) end
        def int16; OwnershipTypeBuilder.new(nil, :int16) end
        def int32; OwnershipTypeBuilder.new(nil, :int32) end
        def int64; OwnershipTypeBuilder.new(nil, :int64) end
        
        def uint8; OwnershipTypeBuilder.new(nil, :uint8) end
        def uint16; OwnershipTypeBuilder.new(nil, :uint16) end
        def uint32; OwnershipTypeBuilder.new(nil, :uint32) end
        def uint64; OwnershipTypeBuilder.new(nil, :uint64) end
        
        # Float types
        def float32; OwnershipTypeBuilder.new(nil, :float32) end
        def float64; OwnershipTypeBuilder.new(nil, :float64) end
        
        # Boolean type
        def bool_type; OwnershipTypeBuilder.new(nil, :bool) end
        
        # Character types
        def char_type; OwnershipTypeBuilder.new(nil, :char) end
        def wchar; OwnershipTypeBuilder.new(nil, :wchar) end
        def char16; OwnershipTypeBuilder.new(nil, :char16) end
        def char32; OwnershipTypeBuilder.new(nil, :char32) end
        
        # String types
        def string_type; OwnershipTypeBuilder.new(nil, :string) end
        def wstring; OwnershipTypeBuilder.new(nil, :wstring) end
        def u16string; OwnershipTypeBuilder.new(nil, :u16string) end
        def u32string; OwnershipTypeBuilder.new(nil, :u32string) end
        
        # Custom type
        def of(type_name)
          OwnershipTypeBuilder.new(type_name, :custom)
        end
        
        # Template type
        def template(name, *params)
          OwnershipTypeBuilder.new([name, *params], :template)
        end
      end
      
      # Include Ownership module in DSL
      def self.included(base)
        base.include Ownership
      end
    end
  end
end
