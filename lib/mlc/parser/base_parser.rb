# frozen_string_literal: true

require_relative "lexer"
require_relative "../ast/nodes"

module MLC
  module Parser
    # Base parser module with shared utilities for all parser components
    # Provides token navigation, consumption, and origin tracking
    module BaseParser
      attr_reader :tokens, :pos, :last_token

      # Initialize parser state
      def initialize_parser(source, filename: nil)
        @lexer = Lexer.new(source, filename: filename)
        @tokens = @lexer.tokenize
        @pos = 0
        @last_token = nil
      end

      # Token navigation

      def current
        @tokens[@pos]
      end

      def peek
        @tokens[@pos + 1] if @pos + 1 < @tokens.length
      end

      def peek_ahead(offset)
        @tokens[@pos + offset] if @pos + offset < @tokens.length
      end

      def eof?
        @pos >= @tokens.length || current.type == :EOF
      end

      def skip_token
        @pos += 1
      end

      # Token consumption

      def consume(expected_type)
        if eof?
          raise "Unexpected EOF, expected #{expected_type}"
        end

        token = current
        if token.type != expected_type
          raise "Expected #{expected_type}, got #{token.type}"
        end

        @pos += 1
        @last_token = token
        token
      end

      def consume_operator(expected_value)
        token = current
        if token.type != :OPERATOR || token.value != expected_value
          raise "Expected operator '#{expected_value}', got #{token.type} '#{token.value}'"
        end
        @pos += 1
        @last_token = token
        token
      end

      def expect_operator(op)
        if current.type != :OPERATOR || current.value != op
          raise "Expected operator '#{op}', got #{current.type}"
        end
        consume(:OPERATOR)
      end

      # Origin tracking for error messages

      def origin_from(token)
        return nil unless token

        SourceOrigin.new(
          file: token.file,
          line: token.line,
          column: token.column
        )
      end

      def attach_origin(node, token)
        return node unless node.is_a?(MLC::AST::Node)
        origin = case token
                 when SourceOrigin
                   token
                 else
                   origin_from(token)
                 end
        return node unless origin
        node.instance_variable_set(:@origin, origin)
        node
      end

      def with_origin(token)
        node = yield
        attach_origin(node, token)
      end

      # Utility methods for common patterns

      def skip_until(*types)
        until eof? || types.include?(current.type)
          @pos += 1
        end
      end

      def parse_comma_separated(end_token, &block)
        items = []
        until eof? || current.type == end_token
          items << block.call
          break if current.type != :COMMA
          consume(:COMMA)
        end
        items
      end
    end
  end
end
