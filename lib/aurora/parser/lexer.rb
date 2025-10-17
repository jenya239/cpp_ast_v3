# frozen_string_literal: true

module Aurora
  module Parser
    class Token
      attr_reader :type, :value, :line, :column
      
      def initialize(type:, value:, line: 1, column: 1)
        @type = type
        @value = value
        @line = line
        @column = column
      end
      
      def to_s
        "#{type}(#{value})"
      end
    end
    
    class Lexer
      KEYWORDS = %w[
        fn type let return if then else while for in do match
        i32 f32 bool void str module export import enum from as
      ].freeze
      
      OPERATORS = %w[
        + - * / % = == != < > <= >= && || !
        . , ; : ( ) { } [ ]
      ].freeze
      
      def initialize(source)
        @source = source
        @pos = 0
        @line = 1
        @column = 1
        @tokens = []
      end
      
      def tokenize
        while @pos < @source.length
          skip_whitespace
          skip_comments
          next if @pos >= @source.length

          char = @source[@pos]
          
          case char
          when /[a-zA-Z_]/
            tokenize_identifier_or_keyword
          when /[0-9]/
            tokenize_number
          when '"'
            tokenize_string
          when /[=+\-*\/%<>!&|.]/
            tokenize_operator
          when '('
            add_token(:LPAREN, char)
            advance
          when ')'
            add_token(:RPAREN, char)
            advance
          when '{'
            add_token(:LBRACE, char)
            advance
          when '}'
            add_token(:RBRACE, char)
            advance
          when '['
            add_token(:LBRACKET, char)
            advance
          when ']'
            add_token(:RBRACKET, char)
            advance
          when ','
            add_token(:COMMA, char)
            advance
          when ';'
            add_token(:SEMICOLON, char)
            advance
          when ':'
            add_token(:COLON, char)
            advance
          else
            advance # Skip unknown characters
          end
        end
        
        add_token(:EOF, "")
        @tokens
      end
      
      private
      
      def skip_whitespace
        while @pos < @source.length && @source[@pos] =~ /\s/
          if @source[@pos] == "\n"
            @line += 1
            @column = 1
          else
            @column += 1
          end
          @pos += 1
        end
      end

      def skip_comments
        # Skip single-line comments //
        if @pos < @source.length - 1 && @source[@pos] == '/' && @source[@pos + 1] == '/'
          # Skip until end of line
          while @pos < @source.length && @source[@pos] != "\n"
            @pos += 1
            @column += 1
          end
        end
      end
      
      def tokenize_identifier_or_keyword
        start = @pos
        while @pos < @source.length && @source[@pos] =~ /[a-zA-Z0-9_]/
          @pos += 1
        end
        
        value = @source[start...@pos]
        @column += value.length
        
        type = KEYWORDS.include?(value) ? value.upcase.to_sym : :IDENTIFIER
        add_token(type, value)
      end
      
      def tokenize_number
        start = @pos
        while @pos < @source.length && @source[@pos] =~ /[0-9]/
          @pos += 1
        end
        
        # Check for decimal point
        if @pos < @source.length && @source[@pos] == '.'
          @pos += 1
          while @pos < @source.length && @source[@pos] =~ /[0-9]/
            @pos += 1
          end
          value = @source[start...@pos]
          @column += value.length
          add_token(:FLOAT_LITERAL, value.to_f)
        else
          value = @source[start...@pos]
          @column += value.length
          add_token(:INT_LITERAL, value.to_i)
        end
      end
      
      def tokenize_string
        @pos += 1 # Skip opening quote
        start = @pos
        @column += 1
        
        while @pos < @source.length && @source[@pos] != '"'
          if @source[@pos] == "\n"
            @line += 1
            @column = 1
          else
            @column += 1
          end
          @pos += 1
        end
        
        value = @source[start...@pos]
        @pos += 1 # Skip closing quote
        @column += 1
        
        add_token(:STRING_LITERAL, value)
      end
      
      def tokenize_operator
        char = @source[@pos]

        # Handle arrow operator ->
        if char == '-' && @pos + 1 < @source.length && @source[@pos + 1] == '>'
          @pos += 2
          @column += 2
          add_token(:ARROW, "->")
          return
        end

        # Handle fat arrow operator =>
        if char == '=' && @pos + 1 < @source.length && @source[@pos + 1] == '>'
          @pos += 2
          @column += 2
          add_token(:FAT_ARROW, "=>")
          return
        end

        # Handle pipe operator |>
        if char == '|' && @pos + 1 < @source.length && @source[@pos + 1] == '>'
          @pos += 2
          @column += 2
          add_token(:PIPE, "|>")
          return
        end

        # Handle multi-character operators
        if @pos + 1 < @source.length
          next_char = @source[@pos + 1]
          two_char = char + next_char

          if %w[== != <= >= && ||].include?(two_char)
            @pos += 2
            @column += 2
            add_token(:OPERATOR, two_char)
            return
          end
        end

        # Special handling for single =
        if char == '='
          @pos += 1
          @column += 1
          add_token(:EQUAL, char)
          return
        end

        @pos += 1
        @column += 1
        add_token(:OPERATOR, char)
      end
      
      def add_token(type, value)
        @tokens << Token.new(type: type, value: value, line: @line, column: @column)
      end
      
      def advance
        @pos += 1
        @column += 1
      end
    end
  end
end
