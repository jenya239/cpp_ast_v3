# frozen_string_literal: true

module CppAst
  module Parsers
    class BaseParser
      attr_reader :tokens, :position, :context_stack
      
      def initialize(lexer)
        @tokens = lexer.tokenize
        @position = 0
        @context_stack = []
      end
      
      def push_context(context_type, name: nil)
        @context_stack.push({ type: context_type, name: name })
      end
      
      def pop_context
        @context_stack.pop
      end
      
      def current_context
        @context_stack.last
      end
      
      def in_context?(context_type)
        @context_stack.any? { |ctx| ctx[:type] == context_type }
      end
      
      def current_class_name
        ctx = @context_stack.reverse.find { |c| c[:type] == :class }
        ctx ? ctx[:name] : nil
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
      
      # Get leading trivia of current token
      def current_leading_trivia
        current_token.leading_trivia
      end
      
      # Get trailing trivia of current token
      def current_trailing_trivia
        current_token.trailing_trivia
      end
      
      # Expect specific token kind
      def expect(kind)
        unless current_token.kind == kind
          raise ParseError, format_error_message(
            "Expected #{kind}, got #{current_token.kind}",
            current_token
          )
        end
        
        advance_raw
      end
      
      # Expect identifier and return token
      def expect_identifier
        unless current_token.kind == :identifier
          raise ParseError, format_error_message(
            "Expected identifier, got #{current_token.kind}",
            current_token
          )
        end
        
        advance_raw
      end
      
      private
      
      # Format error message with context
      def format_error_message(message, token)
        lines = []
        lines << message
        lines << "  at line #{token.line}, column #{token.column}"
        
        # Add parsing context
        if @context_stack.any?
          ctx_str = @context_stack.map { |c| c[:name] || c[:type] }.join(" > ")
          lines << "  context: #{ctx_str}"
        end
        
        # Add code snippet (3 tokens before and after)
        snippet = get_code_snippet(token)
        if snippet
          lines << "  near: #{snippet}"
        end
        
        lines.join("\n")
      end
      
      # Get code snippet around token
      def get_code_snippet(token)
        start_pos = [@position - 3, 0].max
        end_pos = [@position + 3, @tokens.size - 1].min
        
        snippet_tokens = @tokens[start_pos..end_pos]
        snippet = snippet_tokens.map(&:lexeme).join("")
        
        # Trim long snippets
        if snippet.length > 80
          snippet = snippet[0..77] + "..."
        end
        
        snippet.inspect
      end
    end
  end
end

