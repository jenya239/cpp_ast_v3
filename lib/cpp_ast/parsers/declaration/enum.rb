# frozen_string_literal: true

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
        
        if current_token.kind == :colon
          name_suffix = name_suffix + current_token.lexeme + current_token.trailing_trivia
          advance_raw
          
          until current_token.kind == :lbrace || at_end?
            name_suffix << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
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
          rbrace_suffix: rbrace_suffix
        )
        
        [stmt, trailing]
      end
    end
  end
end

