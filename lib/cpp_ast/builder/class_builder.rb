# frozen_string_literal: true

require_relative "types_dsl"

module CppAst
  module Builder
    module ClassBuilder
      # Class builder with best practices
      class ClassBuilder
        attr_reader :name, :members, :base_classes, :modifiers
        
        def initialize(name, **modifiers)
          @name = name
          @members = []
          @base_classes = []
          @modifiers = {
            final: false,
            abstract: false,
            template: false,
            template_params: []
          }.merge(modifiers)
        end
        
        # Make t available in class context
        def t
          @types_instance ||= TypesDSL::Types.new
        end
        
        # Make expression methods available in class context
        def id(name)
          require_relative "expr_builder"
          ExprBuilder::ExprNode.new(Nodes::Identifier.new(name: name.to_s))
        end
        
        def int(value)
          require_relative "expr_builder"
          ExprBuilder::ExprNode.new(Nodes::NumberLiteral.new(value: value.to_s))
        end
        
        def float(value)
          require_relative "expr_builder"
          ExprBuilder::ExprNode.new(Nodes::NumberLiteral.new(value: value.to_s))
        end
        
        def string(value)
          require_relative "expr_builder"
          ExprBuilder::ExprNode.new(Nodes::StringLiteral.new(value: value))
        end
        
        def bool(value)
          require_relative "expr_builder"
          ExprBuilder::ExprNode.new(Nodes::BooleanLiteral.new(value: value))
        end
        
        # Make fn available in class context
        def fn(name, params: [], ret: nil, **modifiers, &block)
          require_relative "function_builder"
          FunctionBuilder::FunctionBuilder.new(name, params: params, ret: ret, **modifiers).tap do |builder|
            builder.body(&block) if block_given?
          end
        end
        
        # Make friend_ available in class context
        def friend_(declaration)
          # Add friend declaration to class
          @members << FriendDeclaration.new(declaration)
        end
        
        # Make class_ available in class context
        def class_(name, **modifiers, &block)
          require_relative "class_builder"
          CppAst::Builder::ClassBuilder::ClassBuilder.new(name, **modifiers).tap do |builder|
            if block_given?
              DSLv2Improved.with_context(builder, &block)
            end
          end
        end
        
        # Add field
        def field(name, type, default: nil, **modifiers)
          field_modifiers = {
            static: false,
            const: false,
            mutable: false,
            inline: false
          }.merge(modifiers)
          
          @members << FieldDeclaration.new(
            name: name,
            type: type,
            default: default,
            modifiers: field_modifiers
          )
          self
        end
        
        # Add constructor
        def ctor(params: [], **modifiers, &block)
          ctor_modifiers = {
            constexpr: true,  # Default to constexpr
            noexcept: true,   # Default to noexcept
            default: false,
            delete: false
          }.merge(modifiers)
          
          if ctor_modifiers[:default]
            @members << DefaultConstructor.new(modifiers: ctor_modifiers)
          elsif ctor_modifiers[:delete]
            @members << DeletedConstructor.new(modifiers: ctor_modifiers)
          else
            @members << Constructor.new(
              params: params,
              modifiers: ctor_modifiers,
              body: block
            )
          end
          self
        end
        
        # Add destructor
        def dtor(**modifiers, &block)
          dtor_modifiers = {
            virtual: false,
            noexcept: true,  # Default to noexcept
            default: false,
            delete: false
          }.merge(modifiers)
          
          if dtor_modifiers[:default]
            @members << DefaultDestructor.new(modifiers: dtor_modifiers)
          elsif dtor_modifiers[:delete]
            @members << DeletedDestructor.new(modifiers: dtor_modifiers)
          else
            @members << Destructor.new(
              modifiers: dtor_modifiers,
              body: block
            )
          end
          self
        end
        
        # Add method
        def def_(name, params: [], ret: nil, **modifiers, &block)
          method_modifiers = {
            const: false,
            noexcept: true,  # Default to noexcept
            virtual: false,
            override: false,
            final: false,
            pure_virtual: false,
            static: false,
            inline: false
          }.merge(modifiers)
          
          @members << MethodDeclaration.new(
            name: name,
            params: params,
            ret: ret,
            modifiers: method_modifiers,
            body: block
          )
          self
        end
        
        # Add base class
        def inherits(base_class, access: :public)
          @base_classes << BaseClass.new(
            name: base_class,
            access: access
          )
          self
        end
        
        # Generate rule of five
        def rule_of_five!
          # Default constructor
          ctor default: true
          
          # Copy constructor
          ctor params: [[t.ref(@name, const: true), :other]], 
               constexpr: true, 
               noexcept: true
          
          # Move constructor
          ctor params: [[t.ref(@name, mutable: true), :other]], 
               constexpr: true, 
               noexcept: true
          
          # Copy assignment
          def_ :operator=, 
               params: [[t.ref(@name, const: true), :other]], 
               ret: t.ref(@name),
               constexpr: true, 
               noexcept: true do
            ret id(:self)
          end
          
          # Move assignment
          def_ :operator=, 
               params: [[t.ref(@name, mutable: true), :other]], 
               ret: t.ref(@name),
               constexpr: true, 
               noexcept: true do
            ret id(:self)
          end
          
          # Destructor
          dtor virtual: false, noexcept: true
          
          self
        end
        
        # Generate rule of zero (default everything)
        def rule_of_zero!
          ctor default: true
          ctor params: [[t.ref(@name, const: true), :other]], default: true
          ctor params: [[t.ref(@name, mutable: true), :other]], default: true
          def_ :operator=, params: [[t.ref(@name, const: true), :other]], ret: t.ref(@name), default: true
          def_ :operator=, params: [[t.ref(@name, mutable: true), :other]], ret: t.ref(@name), default: true
          dtor default: true
          self
        end
        
        # Add access specifier
        def public_section(&block)
          @members << AccessSpecifier.new(access: :public)
          instance_eval(&block) if block_given?
          self
        end
        
        def private_section(&block)
          @members << AccessSpecifier.new(access: :private)
          instance_eval(&block) if block_given?
          self
        end
        
        def protected_section(&block)
          @members << AccessSpecifier.new(access: :protected)
          instance_eval(&block) if block_given?
          self
        end
        
        def to_node
          # Build base classes text
          base_classes_text = @base_classes.map do |base|
            "#{base.access} #{base.name}"
          end.join(", ")
          
          # Convert members to AST nodes
          member_nodes = @members.map(&:to_node)
          
          # Build class declaration
          Nodes::ClassDeclaration.new(
            leading_trivia: "",
            name: @name.to_s,
            members: member_nodes,
            member_trailings: Array.new(member_nodes.size, ""),
            base_classes_text: base_classes_text,
            class_suffix: " ",
            name_suffix: " ",
            lbrace_suffix: "",
            rbrace_suffix: "",
            final: @modifiers[:final],
            abstract: @modifiers[:abstract]
          )
        end
      end
      
      # Field declaration
      class FieldDeclaration
        def initialize(name:, type:, default: nil, modifiers: {})
          @name = name
          @type = type
          @default = default
          @modifiers = modifiers
        end
        
        def to_node
          Nodes::VariableDeclaration.new(
            type: @type.respond_to?(:to_cpp_type) ? @type.to_cpp_type : @type.to_s,
            declarators: [@name.to_s],
            declarator_separators: [],
            type_suffix: " ",
            prefix_modifiers: build_prefix_modifiers
          )
        end
        
        private
        
        def build_prefix_modifiers
          modifiers = []
          modifiers << "static" if @modifiers[:static]
          modifiers << "const" if @modifiers[:const]
          modifiers << "mutable" if @modifiers[:mutable]
          modifiers << "inline" if @modifiers[:inline]
          modifiers.join(" ")
        end
      end
      
      # Constructor declaration
      class Constructor
        def initialize(params:, modifiers:, body:)
          @params = params
          @modifiers = modifiers
          @body = body
        end
        
        def to_node
          param_nodes = @params.map do |param|
            if param.is_a?(Array) && param.size == 2
              type, name = param
              Nodes::Parameter.new(type: type.respond_to?(:to_cpp_type) ? type.to_cpp_type : type.to_s, name: name.to_s)
            else
              raise ArgumentError, "Invalid parameter format: #{param}"
            end
          end
          
          Nodes::FunctionDeclaration.new(
            return_type: "",
            name: @name,
            parameters: param_nodes,
            body: @body&.call&.node,
            return_type_suffix: "",
            lparen_suffix: "",
            rparen_suffix: "",
            param_separators: param_nodes.size > 1 ? Array.new(param_nodes.size - 1, ", ") : [],
            modifiers_text: build_modifiers_text,
            prefix_modifiers: build_prefix_modifiers
          )
        end
        
        private
        
        def build_modifiers_text
          modifiers = []
          modifiers << "noexcept" if @modifiers[:noexcept]
          modifiers.join(" ")
        end
        
        def build_prefix_modifiers
          modifiers = []
          modifiers << "constexpr" if @modifiers[:constexpr]
          modifiers.join(" ")
        end
      end
      
      # Default constructor
      class DefaultConstructor
        def initialize(modifiers:)
          @modifiers = modifiers
        end
        
        def to_node
          Nodes::FunctionDeclaration.new(
            return_type: "",
            name: @name,
            parameters: [],
            body: nil,
            return_type_suffix: "",
            lparen_suffix: "",
            rparen_suffix: "",
            param_separators: [],
            modifiers_text: "= default",
            prefix_modifiers: build_prefix_modifiers
          )
        end
        
        private
        
        def build_prefix_modifiers
          modifiers = []
          modifiers << "constexpr" if @modifiers[:constexpr]
          modifiers.join(" ")
        end
      end
      
      # Deleted constructor
      class DeletedConstructor
        def initialize(modifiers:)
          @modifiers = modifiers
        end
        
        def to_node
          Nodes::FunctionDeclaration.new(
            return_type: "",
            name: @name,
            parameters: [],
            body: nil,
            return_type_suffix: "",
            lparen_suffix: "",
            rparen_suffix: "",
            param_separators: [],
            modifiers_text: "= delete",
            prefix_modifiers: ""
          )
        end
      end
      
      # Destructor
      class Destructor
        def initialize(modifiers:, body:)
          @modifiers = modifiers
          @body = body
        end
        
        def to_node
          Nodes::FunctionDeclaration.new(
            return_type: "",
            name: "~#{@name}",
            parameters: [],
            body: @body&.call&.node,
            return_type_suffix: "",
            lparen_suffix: "",
            rparen_suffix: "",
            param_separators: [],
            modifiers_text: build_modifiers_text,
            prefix_modifiers: build_prefix_modifiers
          )
        end
        
        private
        
        def build_modifiers_text
          modifiers = []
          modifiers << "noexcept" if @modifiers[:noexcept]
          modifiers.join(" ")
        end
        
        def build_prefix_modifiers
          modifiers = []
          modifiers << "virtual" if @modifiers[:virtual]
          modifiers.join(" ")
        end
      end
      
      # Default destructor
      class DefaultDestructor
        def initialize(modifiers:)
          @modifiers = modifiers
        end
        
        def to_node
          Nodes::FunctionDeclaration.new(
            return_type: "",
            name: "~#{@name}",
            parameters: [],
            body: nil,
            return_type_suffix: "",
            lparen_suffix: "",
            rparen_suffix: "",
            param_separators: [],
            modifiers_text: "= default",
            prefix_modifiers: build_prefix_modifiers
          )
        end
        
        private
        
        def build_prefix_modifiers
          modifiers = []
          modifiers << "virtual" if @modifiers[:virtual]
          modifiers.join(" ")
        end
      end
      
      # Deleted destructor
      class DeletedDestructor
        def initialize(modifiers:)
          @modifiers = modifiers
        end
        
        def to_node
          Nodes::FunctionDeclaration.new(
            return_type: "",
            name: "~#{@name}",
            parameters: [],
            body: nil,
            return_type_suffix: "",
            lparen_suffix: "",
            rparen_suffix: "",
            param_separators: [],
            modifiers_text: "= delete",
            prefix_modifiers: ""
          )
        end
      end
      
      # Method declaration
      class MethodDeclaration
        def initialize(name:, params:, ret:, modifiers:, body:)
          @name = name
          @params = params
          @ret = ret
          @modifiers = modifiers
          @body = body
        end
        
        def to_node
          param_nodes = @params.map do |param|
            if param.is_a?(Array) && param.size == 2
              type, name = param
              Nodes::Parameter.new(type: type.respond_to?(:to_cpp_type) ? type.to_cpp_type : type.to_s, name: name.to_s)
            else
              raise ArgumentError, "Invalid parameter format: #{param}"
            end
          end
          
          Nodes::FunctionDeclaration.new(
            return_type: @ret&.to_cpp_type || "void",
            name: @name.to_s,
            parameters: param_nodes,
            body: @body&.call&.node,
            return_type_suffix: " ",
            lparen_suffix: "",
            rparen_suffix: "",
            param_separators: param_nodes.size > 1 ? Array.new(param_nodes.size - 1, ", ") : [],
            modifiers_text: build_modifiers_text,
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
          modifiers.join(" ")
        end
        
        def build_prefix_modifiers
          modifiers = []
          modifiers << "static" if @modifiers[:static]
          modifiers << "virtual" if @modifiers[:virtual]
          modifiers << "inline" if @modifiers[:inline]
          modifiers.join(" ")
        end
      end
      
      # Base class
      class BaseClass
        attr_reader :name, :access
        
        def initialize(name:, access:)
          @name = name
          @access = access
        end
      end
      
      # Access specifier
      class AccessSpecifier
        def initialize(access:)
          @access = access
        end
        
        def to_node
          Nodes::AccessSpecifier.new(access_type: @access.to_s)
        end
      end
      
      # Class DSL methods
      module Classes
        # Main class builder
        def class_(name, **modifiers, &block)
          builder = ClassBuilder.new(name, **modifiers)
          builder.instance_eval(&block) if block_given?
          builder
        end
        
        # Struct builder
        def struct_(name, **modifiers, &block)
          builder = ClassBuilder.new(name, **modifiers)
          builder.instance_eval(&block) if block_given?
          builder
        end
        
        # Union builder
        def union_(name, **modifiers, &block)
          builder = ClassBuilder.new(name, **modifiers)
          builder.instance_eval(&block) if block_given?
          builder
        end
        
        # Template class
        def template_class(generics, name, **modifiers, &block)
          builder = ClassBuilder.new(name, template: true, template_params: generics, **modifiers)
          builder.instance_eval(&block) if block_given?
          builder
        end
      end
      
      # Include Classes module in DSL
      def self.included(base)
        base.include Classes
      end
      
      # Friend declaration
      class FriendDeclaration
        attr_reader :declaration
        
        def initialize(declaration)
          @declaration = declaration
        end
        
        def to_node
          Nodes::FriendDeclaration.new(declaration: @declaration)
        end
      end
    end
  end
end
