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
        
        # Collect leading trivia (whitespace/comments before first statement)
        leading = collect_trivia_string
        
        until at_end?
          begin
            # Parse statement with leading trivia
            stmt, trailing = parse_statement(leading)
            statements << stmt
            statement_trailings << trailing
            
            # Next statement starts immediately (no leading trivia)
            # The trailing from previous statement already consumed
            leading = ""
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
            
            # Collect trailing
            trailing = collect_trivia_string
            
            # Create error statement
            stmt = Nodes::ErrorStatement.new(
              leading_trivia: "",
              error_text: error_text
            )
            statements << stmt
            statement_trailings << trailing
            
            # Reset leading for next statement
            leading = ""
          end
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

