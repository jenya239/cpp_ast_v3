# frozen_string_literal: true

require_relative "types_dsl"
require_relative "expr_builder"
require_relative "control_dsl"
require_relative "function_builder"
require_relative "class_builder"
require_relative "ownership_dsl"

module CppAst
  module Builder
    module DSLv2
      # Main DSL v2 module that combines all components
      include TypesDSL
      include ExprBuilder
      include ControlDSL
      include FunctionBuilder
      include ClassBuilder
      include OwnershipDSL
      
      # Make t available as a method
      def t
        TypesDSL::Types
      end
      
      # Program builder
      class ProgramBuilder
        attr_reader :statements
        
        def initialize
          @statements = []
        end
        
        def add_statement(statement)
          @statements << statement
          self
        end
        
        def to_node
          Nodes::Program.new(
            statements: @statements.map(&:to_node),
            statement_trailings: Array.new(@statements.size, "")
          )
        end
        
        # Delegate DSL methods to the module
        def method_missing(method_name, *args, &block)
          if DSLv2.respond_to?(method_name)
            DSLv2.send(method_name, *args, &block)
          else
            super
          end
        end
        
        def respond_to_missing?(method_name, include_private = false)
          DSLv2.respond_to?(method_name, include_private) || super
        end
      end
      
      # Main program builder
      def program(&block)
        builder = ProgramBuilder.new
        builder.instance_eval(&block) if block_given?
        builder
      end
      
      # Namespace builder
      def namespace(name, &block)
        statements = []
        if block_given?
          # Create a temporary builder to collect statements
          temp_builder = ProgramBuilder.new
          temp_builder.instance_eval(&block)
          statements = temp_builder.statements
        end
        
        Nodes::NamespaceDeclaration.new(
          name: name.to_s,
          body: statements.map(&:to_node),
          namespace_suffix: " ",
          name_suffix: " ",
          lbrace_suffix: "",
          rbrace_suffix: ""
        )
      end
      
      # Include directive
      def include_(path, system: true)
        Nodes::IncludeDirective.new(
          path: path,
          system: system
        )
      end
      
      # Using declaration
      def using_(namespace, *names)
        Nodes::UsingDeclaration.new(
          namespace: namespace.to_s,
          names: names.map(&:to_s)
        )
      end
      
      # Using namespace
      def using_namespace(namespace)
        Nodes::UsingNamespaceDirective.new(
          namespace: namespace.to_s
        )
      end
      
      # Type alias
      def type_alias(name, type)
        Nodes::TypeAlias.new(
          name: name.to_s,
          type: type.to_cpp_type
        )
      end
      
      # Enum declaration
      def enum_(name, *enumerators, **modifiers)
        enum_modifiers = {
          class_enum: false,
          scoped: false,
          underlying_type: nil
        }.merge(modifiers)
        
        Nodes::EnumDeclaration.new(
          name: name.to_s,
          enumerators: enumerators.map do |enumerator|
            if enumerator.is_a?(Hash)
              Nodes::Enumerator.new(
                name: enumerator[:name].to_s,
                value: enumerator[:value]&.node
              )
            else
              Nodes::Enumerator.new(name: enumerator.to_s)
            end
          end,
          enum_suffix: " ",
          name_suffix: " ",
          lbrace_suffix: "",
          rbrace_suffix: "",
          class_enum: enum_modifiers[:class_enum],
          scoped: enum_modifiers[:scoped],
          underlying_type: enum_modifiers[:underlying_type]&.to_cpp_type
        )
      end
      
      # Enum class
      def enum_class(name, underlying_type = nil, *enumerators)
        enum_(name, *enumerators, class_enum: true, scoped: true, underlying_type: underlying_type)
      end
      
      # Template declaration
      def template_(params, &block)
        template_params = params.map do |param|
          if param.is_a?(Hash)
            Nodes::TemplateParameter.new(
              name: param[:name].to_s,
              type: param[:type]&.to_s,
              default: param[:default]&.to_cpp_type
            )
          else
            Nodes::TemplateParameter.new(name: param.to_s)
          end
        end
        
        body = block_given? ? block.call : nil
        
        Nodes::TemplateDeclaration.new(
          parameters: template_params,
          body: body&.to_node
        )
      end
      
      # Concept declaration
      def concept_(name, params, &block)
        concept_params = params.map do |param|
          if param.is_a?(Hash)
            Nodes::ConceptParameter.new(
              name: param[:name].to_s,
              type: param[:type]&.to_s
            )
          else
            Nodes::ConceptParameter.new(name: param.to_s)
          end
        end
        
        body = block_given? ? block.call : nil
        
        Nodes::ConceptDeclaration.new(
          name: name.to_s,
          parameters: concept_params,
          body: body&.to_node
        )
      end
      
      # Module declaration (C++20)
      def module_(name, &block)
        body = block_given? ? block.call : nil
        
        Nodes::ModuleDeclaration.new(
          name: name.to_s,
          body: body&.to_node
        )
      end
      
      # Export declaration (C++20)
      def export_(&block)
        body = block_given? ? block.call : nil
        
        Nodes::ExportDeclaration.new(
          body: body&.to_node
        )
      end
      
      # Import declaration (C++20)
      def import_(module_name)
        Nodes::ImportDeclaration.new(
          module_name: module_name.to_s
        )
      end
      
      # Variable declaration
      def var_(name, type, value = nil, **modifiers)
        var_modifiers = {
          static: false,
          const: false,
          mutable: false,
          inline: false,
          extern: false
        }.merge(modifiers)
        
        Nodes::VariableDeclaration.new(
          type: type.to_cpp_type,
          declarators: [name.to_s],
          declarator_separators: [],
          type_suffix: " ",
          prefix_modifiers: build_prefix_modifiers(var_modifiers),
          default_value: value&.node
        )
      end
      
      # Const declaration
      def const_(name, type, value, **modifiers)
        var_(name, type, value, const: true, **modifiers)
      end
      
      # Static declaration
      def static_(name, type, value = nil, **modifiers)
        var_(name, type, value, static: true, **modifiers)
      end
      
      # Extern declaration
      def extern_(name, type, **modifiers)
        var_(name, type, nil, extern: true, **modifiers)
      end
      
      # Friend declaration
      def friend_(declaration)
        Nodes::FriendDeclaration.new(
          declaration: declaration.to_node
        )
      end
      
      # Comment
      def comment_(text, style: :inline)
        case style
        when :inline
          Nodes::InlineComment.new(text: text)
        when :block
          Nodes::BlockComment.new(text: text)
        when :doxygen
          Nodes::DoxygenComment.new(text: text)
        else
          raise ArgumentError, "Unknown comment style: #{style}"
        end
      end
      
      # Block comment
      def block_comment(text)
        comment_(text, style: :block)
      end
      
      # Doxygen comment
      def doxygen_comment(text)
        comment_(text, style: :doxygen)
      end
      
      # Preprocessor directives
      def define_(name, value = nil)
        Nodes::DefineDirective.new(
          name: name.to_s,
          value: value&.to_s
        )
      end
      
      def ifdef_(name, &block)
        body = block_given? ? block.call : nil
        Nodes::IfdefDirective.new(
          name: name.to_s,
          body: body&.to_node
        )
      end
      
      def ifndef_(name, &block)
        body = block_given? ? block.call : nil
        Nodes::IfndefDirective.new(
          name: name.to_s,
          body: body&.to_node
        )
      end
      
      def endif_
        Nodes::EndifDirective.new
      end
      
      # Pragma directive
      def pragma_(directive)
        Nodes::PragmaDirective.new(
          directive: directive.to_s
        )
      end
      
      # Line directive
      def line_(number, file = nil)
        Nodes::LineDirective.new(
          number: number,
          file: file&.to_s
        )
      end
      
      # Error directive
      def error_(message)
        Nodes::ErrorDirective.new(
          message: message.to_s
        )
      end
      
      # Warning directive
      def warning_(message)
        Nodes::WarningDirective.new(
          message: message.to_s
        )
      end
      
      private
      
      def build_prefix_modifiers(modifiers)
        result = []
        result << "static" if modifiers[:static]
        result << "const" if modifiers[:const]
        result << "mutable" if modifiers[:mutable]
        result << "inline" if modifiers[:inline]
        result << "extern" if modifiers[:extern]
        result.join(" ")
      end
    end
  end
end
