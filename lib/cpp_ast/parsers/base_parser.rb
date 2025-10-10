# frozen_string_literal: true

module CppAst
  module Parsers
    class BaseParser
      attr_reader :tokens, :position
      
      def initialize(lexer)
        @tokens = lexer.tokenize
        @position = 0
      end
      
      def current_token
        @tokens[@position]
      end
      
      def peek_token(offset = 1)
        @tokens[@position + offset]
      end
      
      def at_end?
        current_token.kind == :eof
      end
      
      # Advance WITHOUT collecting trivia
      def advance_raw
        token = current_token
        @position += 1 unless at_end?
        token
      end
      
      # Collect trivia (whitespace, comments, newlines) as string
      def collect_trivia_string
        result = "".dup
        
        while current_token && Token.trivia?(current_token.kind)
          result << current_token.lexeme
          advance_raw
        end
        
        result
      end
      
      # Expect specific token kind
      def expect(kind)
        unless current_token.kind == kind
          raise ParseError, 
            "Expected #{kind}, got #{current_token.kind} at #{current_token.line}:#{current_token.column}"
        end
        
        advance_raw
      end
      
      # Expect identifier and return token
      def expect_identifier
        unless current_token.kind == :identifier
          raise ParseError, 
            "Expected identifier, got #{current_token.kind} at #{current_token.line}:#{current_token.column}"
        end
        
        advance_raw
      end
    end
  end
end

