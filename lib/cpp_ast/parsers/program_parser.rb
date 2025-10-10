# frozen_string_literal: true

module CppAst
  module Parsers
    class ProgramParser < StatementParser
      # Parse entire program
      # Returns Program node
      def parse
        statements = []
        statement_trailings = []
        
        # Collect leading trivia (whitespace/comments before first statement)
        leading = collect_trivia_string
        
        until at_end?
          # Parse statement with leading trivia
          stmt, trailing = parse_statement(leading)
          statements << stmt
          statement_trailings << trailing
          
          # Next statement starts immediately (no leading trivia)
          # The trailing from previous statement already consumed
          leading = ""
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

