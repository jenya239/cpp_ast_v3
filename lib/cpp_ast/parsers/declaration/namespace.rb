# frozen_string_literal: true

module CppAst
  module Parsers
    module NamespaceParser
      def parse_namespace_declaration(leading_trivia)
        namespace_suffix = current_token.trailing_trivia
        expect(:keyword_namespace)
        
        name = "".dup
        name_suffix = ""
        
        if current_token.kind == :identifier
          loop do
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
          
          name_suffix = name_suffix + current_leading_trivia
        end
        
        push_context(:namespace, name: name)
        body, trailing = parse_block_statement("")
        pop_context
        
        stmt = Nodes::NamespaceDeclaration.new(
          leading_trivia: leading_trivia,
          name: name,
          body: body,
          namespace_suffix: namespace_suffix,
          name_suffix: name_suffix
        )
        
        [stmt, trailing]
      end
    end
  end
end

