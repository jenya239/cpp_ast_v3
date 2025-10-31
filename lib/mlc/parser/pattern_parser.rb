# frozen_string_literal: true

module MLC
  module Parser
    # Pattern parsing module
    # Handles parsing of pattern matching patterns (match expressions, destructuring)
    module PatternParser
      # Parse a pattern (entry point)
      # Patterns can be: wildcard, regex, literal, variable, or constructor
      def parse_pattern
        case current.type
        when :UNDERSCORE, :OPERATOR
          parse_wildcard_pattern
        when :REGEX
          parse_regex_pattern
        when :INT_LITERAL
          parse_int_literal_pattern
        when :FLOAT_LITERAL
          parse_float_literal_pattern
        when :IDENTIFIER
          parse_identifier_pattern
        else
          raise "Unexpected token in pattern: #{current}"
        end
      end

      private

      # Parse wildcard pattern: _
      def parse_wildcard_pattern
        if current.type == :UNDERSCORE || (current.type == :OPERATOR && current.value == "_")
          token = current
          consume(current.type)
          return with_origin(token) { AST::Pattern.new(kind: :wildcard, data: {}) }
        end
        raise "Unexpected operator in pattern: #{current.value}"
      end

      # Parse regex pattern: r"..." or r"..." as [x, y, z]
      def parse_regex_pattern
        regex_token = consume(:REGEX)
        regex_data = regex_token.value
        bindings = parse_regex_bindings if current.type == :AS

        with_origin(regex_token) do
          AST::Pattern.new(
            kind: :regex,
            data: {
              pattern: regex_data[:pattern],
              flags: regex_data[:flags],
              bindings: bindings
            }
          )
        end
      end

      # Parse regex bindings: as [x, y, _]
      def parse_regex_bindings
        consume(:AS)
        return [] unless current.type == :LBRACKET

        consume(:LBRACKET)
        bindings = []

        while current.type != :RBRACKET
          bindings << parse_regex_binding
          break unless current.type == :COMMA
          consume(:COMMA)
        end

        consume(:RBRACKET)
        bindings
      end

      # Parse single regex binding: identifier or _
      def parse_regex_binding
        if current.type == :IDENTIFIER
          consume(:IDENTIFIER).value
        elsif current.type == :UNDERSCORE || (current.type == :OPERATOR && current.value == "_")
          consume(current.type)
          "_"
        else
          raise "Expected identifier or _ in regex bindings"
        end
      end

      # Parse integer literal pattern: 42
      def parse_int_literal_pattern
        token = consume(:INT_LITERAL)
        value = token.value.to_i
        with_origin(token) { AST::Pattern.new(kind: :literal, data: {value: value}) }
      end

      # Parse float literal pattern: 3.14
      def parse_float_literal_pattern
        token = consume(:FLOAT_LITERAL)
        value = token.value.to_f
        with_origin(token) { AST::Pattern.new(kind: :literal, data: {value: value}) }
      end

      # Parse identifier pattern: can be variable, constructor, or constructor with fields
      # Examples: x, Some(x), Point{x, y}
      def parse_identifier_pattern
        constructor_token = consume(:IDENTIFIER)
        constructor = constructor_token.value

        case current.type
        when :LPAREN
          parse_constructor_pattern_with_parens(constructor_token, constructor)
        when :LBRACE
          parse_constructor_pattern_with_braces(constructor_token, constructor)
        else
          parse_simple_identifier_pattern(constructor_token, constructor)
        end
      end

      # Parse constructor pattern with parentheses: Some(x)
      def parse_constructor_pattern_with_parens(constructor_token, constructor)
        consume(:LPAREN)
        fields = parse_pattern_fields(:RPAREN)
        consume(:RPAREN)

        with_origin(constructor_token) do
          AST::Pattern.new(
            kind: :constructor,
            data: {name: constructor, fields: fields}
          )
        end
      end

      # Parse constructor pattern with braces: Point{x, y}
      def parse_constructor_pattern_with_braces(constructor_token, constructor)
        consume(:LBRACE)
        bindings = parse_pattern_bindings
        consume(:RBRACE)

        with_origin(constructor_token) do
          AST::Pattern.new(
            kind: :constructor,
            data: {name: constructor, fields: bindings}
          )
        end
      end

      # Parse pattern fields (for constructor patterns)
      def parse_pattern_fields(end_token)
        fields = []

        while current.type != end_token
          if current.type == :IDENTIFIER
            fields << consume(:IDENTIFIER).value
          elsif current.type == :UNDERSCORE || (current.type == :OPERATOR && current.value == "_")
            consume(current.type)
            fields << "_"
          else
            raise "Expected identifier or _ in pattern, got #{current.type}"
          end

          break unless current.type == :COMMA
          consume(:COMMA)
        end

        fields
      end

      # Parse pattern bindings (for record-style patterns)
      def parse_pattern_bindings
        bindings = []

        while current.type != :RBRACE
          bindings << consume(:IDENTIFIER).value
          break unless current.type == :COMMA
          consume(:COMMA)
        end

        bindings
      end

      # Parse simple identifier: determines if it's wildcard, constructor, or variable
      def parse_simple_identifier_pattern(constructor_token, constructor)
        with_origin(constructor_token) do
          if constructor == "_"
            AST::Pattern.new(kind: :wildcard, data: {})
          elsif constructor[0] == constructor[0].upcase
            # Uppercase = constructor with no fields
            AST::Pattern.new(
              kind: :constructor,
              data: {name: constructor, fields: []}
            )
          else
            # Lowercase = variable binding
            AST::Pattern.new(kind: :var, data: {name: constructor})
          end
        end
      end
    end
  end
end
