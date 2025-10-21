# frozen_string_literal: true

module CppAst
  module Builder
    module FunctionBuilder
      # Function builder with best practices
      class FunctionBuilder
        attr_reader :name, :params, :ret_type, :body, :modifiers
        attr_accessor :template_generics
        
        def initialize(name, params: [], ret: nil, **modifiers)
          @name = name
          @params = params
          @ret_type = ret
          @modifiers = {
            const: false,
            noexcept: true,  # Default to noexcept
            nodiscard: true, # Default to nodiscard for non-void
            constexpr: false,
            static: false,
            virtual: false,
            override: false,
            final: false,
            pure_virtual: false,
            inline: false
          }.merge(modifiers)
          @body = nil
          @requires_clause = nil
        end
        
        attr_accessor :requires_clause
        
        def body(&block)
          @body = block.call if block_given?
          self
        end
        
        def const
          @modifiers[:const] = true
          self
        end
        
        def noexcept
          @modifiers[:noexcept] = true
          self
        end
        
        def nodiscard
          @modifiers[:nodiscard] = true
          self
        end
        
        def constexpr
          @modifiers[:constexpr] = true
          self
        end
        
        def static
          @modifiers[:static] = true
          self
        end
        
        def virtual
          @modifiers[:virtual] = true
          self
        end
        
        def override
          @modifiers[:override] = true
          self
        end
        
        def final
          @modifiers[:final] = true
          self
        end
        
        def pure_virtual
          @modifiers[:pure_virtual] = true
          self
        end
        
        def inline
          @modifiers[:inline] = true
          self
        end
        
        def to_node
          # Build parameter list
          param_nodes = @params.map do |param|
            if param.is_a?(Array) && param.size == 2
              # [type, name] format
              type, name = param
              type_str = normalize_type(type)
              Nodes::Parameter.new(
                type: type_str,
                name: name.to_s
              )
            elsif param.is_a?(Hash)
              # {type: type, name: name, default: value} format
              Nodes::Parameter.new(
                type: normalize_type(param[:type]),
                name: param[:name].to_s,
                default_value: param[:default]&.node
              )
            else
              raise ArgumentError, "Invalid parameter format: #{param}"
            end
          end
          
          # Build modifiers text
          modifiers_text = build_modifiers_text
          
          # Build function declaration
          return_type_str = normalize_type(@ret_type)
          if return_type_str.empty?
            if @name == "~"
              return_type_str = ""
            elsif !@name.to_s.empty?
              return_type_str = "void"
            end
          end

          Nodes::FunctionDeclaration.new(
            return_type: return_type_str,
            name: @name.to_s,
            parameters: param_nodes,
            body: @body,
            return_type_suffix: " ",
            lparen_suffix: "",
            rparen_suffix: "",
            param_separators: param_nodes.size > 1 ? Array.new(param_nodes.size - 1, ", ") : [],
            modifiers_text: modifiers_text,
            prefix_modifiers: build_prefix_modifiers
          )
        end
        
        private
        
        def build_modifiers_text
          modifiers = []
          
          modifiers << "const" if @modifiers[:const]
          modifiers << "noexcept" if @modifiers[:noexcept]
          modifiers << "override" if @modifiers[:override]
          modifiers << "final" if @modifiers[:final]
          modifiers << "= 0" if @modifiers[:pure_virtual]
          
          modifiers.empty? ? "" : " " + modifiers.join(" ")
        end
        
        def build_prefix_modifiers
          modifiers = []
          
          modifiers << "static" if @modifiers[:static]
          modifiers << "virtual" if @modifiers[:virtual]
          modifiers << "constexpr" if @modifiers[:constexpr]
          modifiers << "inline" if @modifiers[:inline]
          
          modifiers.empty? ? "" : "#{modifiers.join(' ')} "
        end

        def normalize_type(type)
          return "" if type.nil?

          if type.respond_to?(:to_cpp_type)
            type.to_cpp_type.to_s
          else
            type.to_s
          end
        end
      end
      
      # Function DSL methods
      module Functions
        # Main function builder
        def fn(name, params: [], ret: nil, **modifiers, &block)
          builder = FunctionBuilder.new(name, params: params, ret: ret, **modifiers)
          builder.body(&block) if block_given?
          builder
        end
        
        # Constructor builder
        def ctor(params: [], **modifiers, &block)
          builder = FunctionBuilder.new("", params: params, ret: nil, **modifiers)
          builder.body(&block) if block_given?
          builder
        end
        
        # Destructor builder
        def dtor(**modifiers, &block)
          builder = FunctionBuilder.new("~", params: [], ret: nil, **modifiers)
          builder.body(&block) if block_given?
          builder
        end
        
        # Method builder (for classes)
        def def_(name, params: [], ret: nil, **modifiers, &block)
          builder = FunctionBuilder.new(name, params: params, ret: ret, **modifiers)
          builder.body(&block) if block_given?
          builder
        end
        
        # Template function
        def template_fn(generics, name, params: [], ret: nil, **modifiers, &block)
          builder = FunctionBuilder.new(name, params: params, ret: ret, **modifiers)
          builder.body(&block) if block_given?
          builder.template_generics = generics
          builder
        end
        
        # Lambda function
        def lambda_fn(params: [], ret: nil, **modifiers, &block)
          builder = FunctionBuilder.new("", params: params, ret: ret, **modifiers)
          builder.body(&block) if block_given?
          builder.modifiers[:lambda] = true
          builder
        end
        
        # Function with concepts/requires
        def fn_with_requires(name, params: [], ret: nil, requires: nil, **modifiers, &block)
          builder = FunctionBuilder.new(name, params: params, ret: ret, **modifiers)
          builder.body(&block) if block_given?
          builder.requires_clause = requires
          builder
        end
      end
      
      # Include Functions module in DSL
      def self.included(base)
        base.include Functions
      end
      
      # Also include Functions when FunctionBuilder is included
      include Functions
    end
  end
end
