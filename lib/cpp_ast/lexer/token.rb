# frozen_string_literal: true

module CppAst
  class Token
    attr_reader :kind, :lexeme, :line, :column
    
    TRIVIA_KINDS = [:whitespace, :comment, :newline, :preprocessor, :attribute].freeze
    
    def initialize(kind:, lexeme:, line:, column:)
      @kind = kind
      @lexeme = lexeme
      @line = line
      @column = column
    end
    
    def self.trivia?(kind)
      TRIVIA_KINDS.include?(kind)
    end
    
    def trivia?
      self.class.trivia?(kind)
    end
    
    def to_s
      "Token(#{kind}, #{lexeme.inspect}, #{line}:#{column})"
    end
  end
end

