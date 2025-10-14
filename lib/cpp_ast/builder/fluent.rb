# frozen_string_literal: true

module CppAst
  module Builder
    # Fluent API для установки trivia в нодах
    module Fluent
      # Common methods для всех нод
      def with_leading(trivia)
        dup.tap { |n| n.leading_trivia = trivia }
      end
      
      # Expression-specific fluent methods
      module Expression
        # Expressions обычно не имеют leading_trivia
      end
      
      # Statement-specific fluent methods
      module Statement
        include Fluent
      end
      
      # Specific node fluent methods
      module BinaryExpression
        include Fluent
        
        def with_operator_prefix(trivia)
          dup.tap { |n| n.operator_prefix = trivia }
        end
        
        def with_operator_suffix(trivia)
          dup.tap { |n| n.operator_suffix = trivia }
        end
      end
      
      module UnaryExpression
        include Fluent
        
        def with_operator_suffix(trivia)
          dup.tap { |n| n.operator_suffix = trivia }
        end
      end
      
      module ParenthesizedExpression
        include Fluent
        
        def with_open_paren_suffix(trivia)
          dup.tap { |n| n.open_paren_suffix = trivia }
        end
        
        def with_close_paren_prefix(trivia)
          dup.tap { |n| n.close_paren_prefix = trivia }
        end
      end
      
      module FunctionCallExpression
        include Fluent
        
        def with_lparen_suffix(trivia)
          dup.tap { |n| n.lparen_suffix = trivia }
        end
        
        def with_rparen_prefix(trivia)
          dup.tap { |n| n.rparen_prefix = trivia }
        end
        
        def with_argument_separators(separators)
          dup.tap { |n| n.argument_separators = separators }
        end
      end
      
      module MemberAccessExpression
        include Fluent
        
        def with_operator_prefix(trivia)
          dup.tap { |n| n.operator_prefix = trivia }
        end
        
        def with_operator_suffix(trivia)
          dup.tap { |n| n.operator_suffix = trivia }
        end
      end
      
      module ReturnStatement
        include Statement
        
        def with_keyword_suffix(trivia)
          dup.tap { |n| n.keyword_suffix = trivia }
        end
      end
      
      module BlockStatement
        include Statement
        
        def with_lbrace_suffix(trivia)
          dup.tap { |n| n.lbrace_suffix = trivia }
        end
        
        def with_rbrace_prefix(trivia)
          dup.tap { |n| n.rbrace_prefix = trivia }
        end
        
        def with_statement_trailings(trailings)
          dup.tap { |n| n.statement_trailings = trailings }
        end
      end
      
      module FunctionDeclaration
        include Statement
        
        def with_return_type_suffix(trivia)
          dup.tap { |n| n.return_type_suffix = trivia }
        end
        
        def with_lparen_suffix(trivia)
          dup.tap { |n| n.lparen_suffix = trivia }
        end
        
        def with_rparen_suffix(trivia)
          dup.tap { |n| n.rparen_suffix = trivia }
        end
        
        def with_param_separators(separators)
          dup.tap { |n| n.param_separators = separators }
        end
        
        def with_modifiers_text(text)
          dup.tap { |n| n.modifiers_text = text }
        end
        
        def with_prefix_modifiers(text)
          dup.tap { |n| n.prefix_modifiers = text }
        end
        
        # Modern C++ modifiers - Phase 2
        def deleted
          dup.tap { |n| 
            n.rparen_suffix = ""
            n.modifiers_text = " = delete"
            n.body = nil  # deleted functions have no body
          }
        end
        
        def defaulted
          dup.tap { |n| 
            n.rparen_suffix = " = default"
            n.body = nil
          }
        end
        
        def noexcept
          dup.tap { |n| n.modifiers_text += " noexcept" }
        end
        
        def explicit
          dup.tap { |n| n.prefix_modifiers = "explicit " + n.prefix_modifiers }
        end
        
        def constexpr
          dup.tap { |n| n.prefix_modifiers = "constexpr " + n.prefix_modifiers }
        end
        
        def const
          dup.tap { |n| n.modifiers_text += " const" }
        end
        
        def inline
          dup.tap { |n| n.prefix_modifiers = "inline " + n.prefix_modifiers }
        end
        
        def nodiscard
          dup.tap { |n| n.prefix_modifiers = "[[nodiscard]] " + n.prefix_modifiers }
        end
        
        # C++11 attributes support - Phase 1
        def attribute(name)
          dup.tap { |n| n.prefix_modifiers = "[[#{name}]] " + n.prefix_modifiers }
        end
        
        def maybe_unused
          dup.tap { |n| n.prefix_modifiers = "[[maybe_unused]] " + n.prefix_modifiers }
        end
        
        def deprecated
          dup.tap { |n| n.prefix_modifiers = "[[deprecated]] " + n.prefix_modifiers }
        end
        
        def deprecated_with_message(message)
          dup.tap { |n| n.prefix_modifiers = "[[deprecated(\"#{message}\")]] " + n.prefix_modifiers }
        end
        
        def scoped_name(class_name)
          dup.tap { |n| n.name = "#{class_name}::#{n.name}" }
        end
        
        def static
          dup.tap { |n| n.prefix_modifiers = "static " + n.prefix_modifiers }
        end
        
        # Virtual methods support - Phase 1
        def virtual
          dup.tap { |n| n.prefix_modifiers = "virtual " + n.prefix_modifiers }
        end
        
        def override
          dup.tap { |n| n.modifiers_text += " override" }
        end
        
        def final
          dup.tap { |n| n.modifiers_text += " final" }
        end
        
        def pure_virtual
          dup.tap { |n| 
            n.prefix_modifiers = "virtual " + n.prefix_modifiers
            n.rparen_suffix = " = 0"
            n.body = nil  # pure virtual functions have no body
          }
        end
        
        # Inline method body for class methods
        def inline_body(body)
          dup.tap { |n| 
            n.body = body
            n.prefix_modifiers = "inline " + n.prefix_modifiers
          }
        end
        
        # Constructor initializer list
        def with_initializer_list(initializer_list)
          dup.tap { |n| n.initializer_list = initializer_list }
        end
      end
      
      module VariableDeclaration
        include Statement
        
        def with_type_suffix(trivia)
          dup.tap { |n| n.type_suffix = trivia }
        end
        
        def with_declarator_separators(separators)
          dup.tap { |n| n.declarator_separators = separators }
        end
        
        # Static and inline modifiers for variables - Phase 3
        def static
          dup.tap { |n| n.prefix_modifiers = "static " + n.prefix_modifiers }
        end
        
        def inline
          dup.tap { |n| n.prefix_modifiers = "inline " + n.prefix_modifiers }
        end
        
        def constexpr
          dup.tap { |n| n.prefix_modifiers = "constexpr " + n.prefix_modifiers }
        end
        
        def const
          dup.tap { |n| n.prefix_modifiers = "const " + n.prefix_modifiers }
        end
      end
      
      # C++20 Coroutines - Phase 4
      module CoroutineFunction
        include Statement
        
        def coroutine
          dup.tap { |n| n.prefix_modifiers = "coroutine " + n.prefix_modifiers }
        end
      end
      
      module IfStatement
        include Statement
        
        def with_if_suffix(trivia)
          dup.tap { |n| n.if_suffix = trivia }
        end
        
        def with_condition_lparen_suffix(trivia)
          dup.tap { |n| n.condition_lparen_suffix = trivia }
        end
        
        def with_condition_rparen_suffix(trivia)
          dup.tap { |n| n.condition_rparen_suffix = trivia }
        end
        
        def with_else_prefix(trivia)
          dup.tap { |n| n.else_prefix = trivia }
        end
        
        def with_else_suffix(trivia)
          dup.tap { |n| n.else_suffix = trivia }
        end
      end
      
      module Program
        def with_statement_trailings(trailings)
          dup.tap { |n| n.statement_trailings = trailings }
        end
      end
      
      module ClassDeclaration
        include Statement
        
        def with_base_classes(base_classes_text)
          dup.tap { |n| n.base_classes_text = base_classes_text }
        end
      end
      
      module LambdaExpression
        include Fluent
        
        def with_capture_suffix(trivia)
          dup.tap { |n| n.capture_suffix = trivia }
        end
        
        def with_params_suffix(trivia)
          dup.tap { |n| n.params_suffix = trivia }
        end
      end
      
      module TemplateDeclaration
        include Statement
        
        def with_template_suffix(trivia)
          dup.tap { |n| n.template_suffix = trivia }
        end
        
        def with_less_suffix(trivia)
          dup.tap { |n| n.less_suffix = trivia }
        end
        
        def with_params_suffix(trivia)
          dup.tap { |n| n.params_suffix = trivia }
        end
        
        def specialized
          dup.tap { |n| n.template_params = ""; n.less_suffix = ""; n.params_suffix = " "; n.template_suffix = "" }
        end
      end
    end
  end
end

# Extend nodes with fluent methods
CppAst::Nodes::BinaryExpression.include(CppAst::Builder::Fluent::BinaryExpression)
CppAst::Nodes::UnaryExpression.include(CppAst::Builder::Fluent::UnaryExpression)
CppAst::Nodes::ParenthesizedExpression.include(CppAst::Builder::Fluent::ParenthesizedExpression)
CppAst::Nodes::FunctionCallExpression.include(CppAst::Builder::Fluent::FunctionCallExpression)
CppAst::Nodes::MemberAccessExpression.include(CppAst::Builder::Fluent::MemberAccessExpression)
CppAst::Nodes::LambdaExpression.include(CppAst::Builder::Fluent::LambdaExpression)

# Statements
CppAst::Nodes::ExpressionStatement.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::ReturnStatement.include(CppAst::Builder::Fluent::ReturnStatement)
CppAst::Nodes::BlockStatement.include(CppAst::Builder::Fluent::BlockStatement)
CppAst::Nodes::IfStatement.include(CppAst::Builder::Fluent::IfStatement)
CppAst::Nodes::WhileStatement.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::DoWhileStatement.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::ForStatement.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::SwitchStatement.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::BreakStatement.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::ContinueStatement.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::ErrorStatement.include(CppAst::Builder::Fluent::Statement)

# Declarations
CppAst::Nodes::FunctionDeclaration.include(CppAst::Builder::Fluent::FunctionDeclaration)
CppAst::Nodes::VariableDeclaration.include(CppAst::Builder::Fluent::VariableDeclaration)
CppAst::Nodes::ClassDeclaration.include(CppAst::Builder::Fluent::ClassDeclaration)
CppAst::Nodes::StructDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::EnumDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::UsingDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::AccessSpecifier.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::NamespaceDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::TemplateDeclaration.include(CppAst::Builder::Fluent::TemplateDeclaration)

# Other
CppAst::Nodes::Program.include(CppAst::Builder::Fluent::Program)

# Comments - Phase 2
CppAst::Nodes::InlineComment.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::BlockComment.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::DoxygenComment.include(CppAst::Builder::Fluent::Statement)

# Preprocessor - Phase 2
CppAst::Nodes::DefineDirective.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::IfdefDirective.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::IfndefDirective.include(CppAst::Builder::Fluent::Statement)

# C++20 Concepts - Phase 4
CppAst::Nodes::ConceptDeclaration.include(CppAst::Builder::Fluent::Statement)

# C++20 Modules - Phase 4
CppAst::Nodes::ModuleDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::ImportDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::ExportDeclaration.include(CppAst::Builder::Fluent::Statement)

# C++20 Coroutines - Phase 4
CppAst::Nodes::CoAwaitExpression.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::CoYieldExpression.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::CoReturnStatement.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::FunctionDeclaration.include(CppAst::Builder::Fluent::CoroutineFunction)

