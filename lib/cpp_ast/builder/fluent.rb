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
      end
      
      module VariableDeclaration
        include Statement
        
        def with_type_suffix(trivia)
          dup.tap { |n| n.type_suffix = trivia }
        end
        
        def with_declarator_separators(separators)
          dup.tap { |n| n.declarator_separators = separators }
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
CppAst::Nodes::ClassDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::StructDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::EnumDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::UsingDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::AccessSpecifier.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::NamespaceDeclaration.include(CppAst::Builder::Fluent::Statement)
CppAst::Nodes::TemplateDeclaration.include(CppAst::Builder::Fluent::TemplateDeclaration)

# Other
CppAst::Nodes::Program.include(CppAst::Builder::Fluent::Program)

