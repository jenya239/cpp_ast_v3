# frozen_string_literal: true

module CppAst
  module Parsers
    class ProgramParser < StatementParser
      attr_accessor :errors
      
      def initialize(lexer)
        super(lexer)
        @errors = []
      end
      
      # Parse entire program
      # Returns Program node
      def parse
        statements = []
        statement_trailings = []
        
        # Leading trivia (whitespace/comments before first statement)
        # Now comes from token's leading_trivia
        leading = current_leading_trivia
        
        until at_end?
          begin
            # Parse statement with leading trivia
            stmt, trailing = parse_statement(leading)
            statements << stmt
            statement_trailings << trailing
            
            # Next statement's leading trivia comes from next token
            leading = current_leading_trivia
          rescue ParseError => e
            # Error recovery: collect error info and skip to next statement
            @errors << { message: e.message, position: @position }
            
            # Create error statement with the problematic code
            error_text = "".dup
            error_text << leading
            
            # Skip tokens until we find ; or } or reach end
            until at_end? || [:semicolon, :rbrace].include?(current_token.kind)
              error_text << current_token.lexeme
              advance_raw
            end
            
            # Include the ; or } in error text
            if !at_end?
              error_text << current_token.lexeme
              advance_raw
            end
            
            # Trailing comes from current token
            trailing = current_leading_trivia
            
            # Create error statement
            stmt = Nodes::ErrorStatement.new(
              leading_trivia: "",
              error_text: error_text
            )
            statements << stmt
            statement_trailings << trailing
            
            # Next statement's leading trivia
            leading = current_leading_trivia
          end
        end
        
        # Add EOF leading_trivia to trailing of last statement
        if !statements.empty? && at_end?
          statement_trailings[-1] = statement_trailings[-1] + current_leading_trivia
        end
        
        # Create program node
        Nodes::Program.new(
          statements: statements,
          statement_trailings: statement_trailings
        )
      end
    end
  end
end

