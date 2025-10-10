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
        
        lbrace_suffix = current_token.trailing_trivia
        expect(:lbrace)
        
        push_context(:namespace, name: name)
        
        statements = []
        statement_trailings = []
        statement_leading = ""
        
        until current_token.kind == :rbrace || at_end?
          statement_leading += current_leading_trivia
          stmt, trailing = parse_statement(statement_leading)
          statements << stmt
          statement_trailings << trailing
          statement_leading = ""
        end
        
        pop_context
        
        rbrace_prefix = current_leading_trivia
        trailing = current_token.trailing_trivia
        expect(:rbrace)
        
        body = Nodes::BlockStatement.new(
          leading_trivia: "",
          statements: statements,
          statement_trailings: statement_trailings,
          lbrace_suffix: lbrace_suffix,
          rbrace_prefix: rbrace_prefix
        )
        
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

