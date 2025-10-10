# frozen_string_literal: true

module CppAst
  module Parsers
    module ClassParser
      def parse_class_like_declaration(leading_trivia, keyword_kind, node_class)
        keyword_suffix = current_token.trailing_trivia
        expect(keyword_kind)
        
        raise ParseError, "Expected #{keyword_kind == :keyword_class ? 'class' : 'struct'} name" unless current_token.kind == :identifier
        
        name = current_token.lexeme
        name_suffix = current_token.trailing_trivia
        advance_raw
        
        base_classes_text = ""
        if current_token.kind == :colon
          base_classes_text = name_suffix.dup
          name_suffix = ""
          base_classes_text << current_token.lexeme << current_token.trailing_trivia
          advance_raw
          
          until current_token.kind == :lbrace || at_end?
            base_classes_text << current_leading_trivia << current_token.lexeme << current_token.trailing_trivia
            advance_raw
          end
        end
        
        lbrace_suffix = current_token.trailing_trivia
        expect(:lbrace)
        
        push_context(:class, name: name)
        
        members = []
        member_trailings = []
        member_leading = ""
        
        until current_token.kind == :rbrace || at_end?
          member_leading += current_leading_trivia
          
          if [:keyword_public, :keyword_private, :keyword_protected].include?(current_token.kind)
            keyword = current_token.lexeme
            _colon_prefix = current_token.trailing_trivia
            advance_raw
            colon_suffix = current_token.trailing_trivia
            expect(:colon)
            
            members << Nodes::AccessSpecifier.new(
              leading_trivia: member_leading,
              keyword: keyword,
              colon_suffix: colon_suffix
            )
            member_trailings << ""
            member_leading = ""
          else
            member, trailing = parse_statement(member_leading)
            members << member
            member_trailings << trailing
            member_leading = ""
          end
        end
        
        pop_context
        
        rbrace_suffix = current_leading_trivia
        _semicolon_prefix = current_token.trailing_trivia
        expect(:rbrace)
        trailing = current_token.trailing_trivia
        expect(:semicolon)
        
        params = {
          leading_trivia: leading_trivia,
          name: name,
          members: members,
          member_trailings: member_trailings,
          name_suffix: name_suffix,
          lbrace_suffix: lbrace_suffix,
          rbrace_suffix: rbrace_suffix,
          base_classes_text: base_classes_text
        }
        params[keyword_kind == :keyword_class ? :class_suffix : :struct_suffix] = keyword_suffix
        
        [node_class.new(**params), trailing]
      end
      
      def parse_class_declaration(leading_trivia)
        parse_class_like_declaration(leading_trivia, :keyword_class, Nodes::ClassDeclaration)
      end
      
      def parse_struct_declaration(leading_trivia)
        parse_class_like_declaration(leading_trivia, :keyword_struct, Nodes::StructDeclaration)
      end
    end
  end
end

