# frozen_string_literal: true

module CppAst
  module Nodes
    # ExpressionStatement: `foo;`
    class ExpressionStatement < Statement
      attr_accessor :expression
      
      def initialize(leading_trivia: "", expression:)
        super(leading_trivia: leading_trivia)
        @expression = expression
      end
      
      def to_source
        "#{leading_trivia}#{expression.to_source};"
      end
    end
    
    # ReturnStatement: `return 42;`
    class ReturnStatement < Statement
      attr_accessor :expression, :keyword_suffix
      
      def initialize(leading_trivia: "", expression:, keyword_suffix: " ")
        super(leading_trivia: leading_trivia)
        @expression = expression
        @keyword_suffix = keyword_suffix
      end
      
      def to_source
        "#{leading_trivia}return#{keyword_suffix}#{expression.to_source};"
      end
    end
    
    # Program: Top-level container
    # Manages spacing between statements
    class Program < Node
      attr_accessor :statements, :statement_trailings
      
      def initialize(statements:, statement_trailings:)
        @statements = statements
        @statement_trailings = statement_trailings
      end
      
      def to_source
        statements.zip(statement_trailings).map { |stmt, trailing|
          stmt.to_source + trailing
        }.join
      end
    end
  end
end

