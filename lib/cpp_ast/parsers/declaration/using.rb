# frozen_string_literal: true

module CppAst
  module Parsers
    module UsingParser
      def parse_using_declaration(leading_trivia)
        using_suffix = current_token.trailing_trivia
        expect(:keyword_using)
        
        if current_token.kind == :keyword_namespace
          namespace_suffix = current_token.trailing_trivia
          advance_raw
          
          name = "".dup
          name_suffix = ""
          loop do
            unless current_token.kind == :identifier
              raise ParseError, "Expected namespace name"
            end
            
            name << current_token.lexeme
            trivia_before_colon = current_token.trailing_trivia
            advance_raw
            
            if current_token.kind == :colon_colon
              name << trivia_before_colon << current_token.lexeme
              advance_raw
            else
              name_suffix = trivia_before_colon
              break
            end
          end
          
          _semicolon_prefix = current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          
          stmt = Nodes::UsingDeclaration.new(
            leading_trivia: leading_trivia,
            kind: :namespace,
            name: name + name_suffix,
            using_suffix: using_suffix,
            namespace_suffix: namespace_suffix
          )
          
          return [stmt, trailing]
        end
        
        name = "".dup
        after_name = ""
        loop do
          unless current_token.kind == :identifier
            raise ParseError, "Expected identifier in using declaration"
          end
          
          name << current_token.lexeme
          trivia_before_colon = current_token.trailing_trivia
          advance_raw
          
          if current_token.kind == :colon_colon
            name << trivia_before_colon << current_token.lexeme
            advance_raw
          else
            after_name = trivia_before_colon
            break
          end
        end
        
        after_name_extra = current_leading_trivia
        if current_token.kind == :equals
          equals_prefix = after_name + after_name_extra
          equals_suffix = current_token.trailing_trivia
          advance_raw
          
          alias_target = "".dup
          until current_token.kind == :semicolon || at_end?
            alias_target << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
          
          _semicolon_prefix = current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          
          stmt = Nodes::UsingDeclaration.new(
            leading_trivia: leading_trivia,
            kind: :alias,
            name: name,
            alias_target: alias_target,
            using_suffix: using_suffix,
            equals_prefix: equals_prefix,
            equals_suffix: equals_suffix
          )
          
          return [stmt, trailing]
        else
          _semicolon_prefix = after_name + after_name_extra + current_leading_trivia
          trailing = current_token.trailing_trivia
          expect(:semicolon)
          
          stmt = Nodes::UsingDeclaration.new(
            leading_trivia: leading_trivia,
            kind: :name,
            name: name,
            using_suffix: using_suffix
          )
          
          return [stmt, trailing]
        end
      end
    end
  end
end

