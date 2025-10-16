# frozen_string_literal: true

require_relative '../../builder/formatting_context'

module CppAst
  module Parsers
    module EnumParser
      def parse_enum_declaration(leading_trivia)
        enum_suffix = current_token.trailing_trivia
        expect(:keyword_enum)

        class_keyword = ""
        class_suffix = ""
        if [:keyword_class, :keyword_struct].include?(current_token.kind)
          class_keyword = current_token.lexeme
          class_suffix = current_token.trailing_trivia
          advance_raw
        end

        name = ""
        name_suffix = ""
        if current_token.kind == :identifier
          name = current_token.lexeme
          name_suffix = current_token.trailing_trivia
          advance_raw
        end

        underlying_type = nil
        colon_prefix = ""
        colon_suffix = ""
        if current_token.kind == :colon
          # Apply FormattingContext default for space before colon in underlying type
          colon_prefix = name_suffix.empty? ? " " : name_suffix
          name_suffix = Builder::FormattingContext.get(:name_suffix_with_underlying)

          colon_suffix = current_token.trailing_trivia
          advance_raw

          underlying_type = "".dup
          until current_token.kind == :lbrace || at_end?
            underlying_type << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end

          # Reset name_suffix since we used it for colon_prefix
          name_suffix = ""
        end
        
        lbrace_suffix = current_token.trailing_trivia
        expect(:lbrace)
        
        enumerators = "".dup
        until current_token.kind == :rbrace || at_end?
          enumerators << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
          advance_raw
        end
        
        rbrace_suffix = current_leading_trivia
        _semicolon_prefix = current_token.trailing_trivia
        expect(:rbrace)
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
        stmt = Nodes::EnumDeclaration.new(
          leading_trivia: leading_trivia,
          name: name,
          enumerators: enumerators,
          enum_suffix: enum_suffix,
          class_keyword: class_keyword,
          class_suffix: class_suffix,
          name_suffix: name_suffix,
          lbrace_suffix: lbrace_suffix,
          rbrace_suffix: rbrace_suffix,
          underlying_type: underlying_type,
          colon_prefix: colon_prefix,
          colon_suffix: colon_suffix
        )
        
        [stmt, trailing]
      end
    end
  end
end

