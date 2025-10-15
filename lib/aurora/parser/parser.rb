# frozen_string_literal: true

require_relative "lexer"
require_relative "../ast/nodes"

module Aurora
  module Parser
    class Parser
      def initialize(source)
        @lexer = Lexer.new(source)
        @tokens = @lexer.tokenize
        @pos = 0
      end
      
      def parse
        parse_program
      end
      
      private
      
      def parse_program
        declarations = []
        
        while !eof?
          case current.type
          when :FN
            declarations << parse_function
          when :TYPE
            declarations << parse_type_decl
          else
            break
          end
        end
        
        AST::Program.new(declarations: declarations)
      end
      
      def parse_function
        consume(:FN)
        name = consume(:IDENTIFIER).value
        
        consume(:LPAREN)
        params = parse_params
        consume(:RPAREN)
        
        consume(:ARROW)
        ret_type = parse_type
        
        consume(:EQUAL)
        body = parse_expression
        
        AST::FuncDecl.new(
          name: name,
          params: params,
          ret_type: ret_type,
          body: body
        )
      end
      
      def parse_params
        params = []
        
        while current.type != :RPAREN
          name = consume(:IDENTIFIER).value
          consume(:COLON)
          type = parse_type
          
          params << AST::Param.new(name: name, type: type)
          
          if current.type == :COMMA
            consume(:COMMA)
          else
            break
          end
        end
        
        params
      end
      
      def parse_type_decl
        consume(:TYPE)
        name = consume(:IDENTIFIER).value
        consume(:EQUAL)
        
        if current.type == :LBRACE
          type = parse_record_type
        else
          type = parse_type
        end
        
        AST::TypeDecl.new(name: name, type: type)
      end
      
      def parse_type
        case current.type
        when :I32
          consume(:I32)
          AST::PrimType.new(name: "i32")
        when :F32
          consume(:F32)
          AST::PrimType.new(name: "f32")
        when :BOOL
          consume(:BOOL)
          AST::PrimType.new(name: "bool")
        when :VOID
          consume(:VOID)
          AST::PrimType.new(name: "void")
        when :IDENTIFIER
          name = consume(:IDENTIFIER).value
          AST::PrimType.new(name: name)
        when :LBRACE
          parse_record_type
        else
          raise "Unexpected token: #{current}"
        end
      end
      
      def parse_record_type
        consume(:LBRACE)
        fields = []
        
        while current.type != :RBRACE
          field_name = consume(:IDENTIFIER).value
          consume(:COLON)
          field_type = parse_type
          
          fields << {name: field_name, type: field_type}
          
          if current.type == :COMMA
            consume(:COMMA)
          else
            break
          end
        end
        
        consume(:RBRACE)
        AST::RecordType.new(name: "record", fields: fields)
      end
      
      def parse_expression
        parse_let_expression
      end
      
      def parse_let_expression
        if current.type == :LET
          consume(:LET)
          name = consume(:IDENTIFIER).value
          consume(:EQUAL)
          value = parse_equality
          # Skip newline if present
          if current.type == :SEMICOLON
            consume(:SEMICOLON)
          end
          body = parse_expression
          
          AST::Let.new(name: name, value: value, body: body)
        else
          parse_equality
        end
      end
      
      def parse_equality
        left = parse_comparison
        
        while current.type == :OPERATOR && %w[== !=].include?(current.value)
          op = consume(:OPERATOR).value
          right = parse_comparison
          left = AST::BinaryOp.new(op: op, left: left, right: right)
        end
        
        left
      end
      
      def parse_comparison
        left = parse_addition
        
        while current.type == :OPERATOR && %w[< > <= >=].include?(current.value)
          op = consume(:OPERATOR).value
          right = parse_addition
          left = AST::BinaryOp.new(op: op, left: left, right: right)
        end
        
        left
      end
      
      def parse_addition
        left = parse_multiplication
        
        while current.type == :OPERATOR && %w[+ -].include?(current.value)
          op = consume(:OPERATOR).value
          right = parse_multiplication
          left = AST::BinaryOp.new(op: op, left: left, right: right)
        end
        
        left
      end
      
      def parse_multiplication
        left = parse_primary
        
        while current.type == :OPERATOR && %w[* / %].include?(current.value)
          op = consume(:OPERATOR).value
          right = parse_primary
          left = AST::BinaryOp.new(op: op, left: left, right: right)
        end
        
        left
      end
      
      def parse_primary
        case current.type
        when :INT_LITERAL
          value = consume(:INT_LITERAL).value
          AST::IntLit.new(value: value)
        when :FLOAT_LITERAL
          value = consume(:FLOAT_LITERAL).value
          AST::FloatLit.new(value: value)
        when :IDENTIFIER
          name = consume(:IDENTIFIER).value
          
          if current.type == :LPAREN
            # Function call
            consume(:LPAREN)
            args = parse_args
            consume(:RPAREN)
            AST::Call.new(callee: AST::VarRef.new(name: name), args: args)
          elsif current.type == :LBRACE
            # Record literal
            consume(:LBRACE)
            fields = parse_record_fields
            consume(:RBRACE)
            AST::RecordLit.new(type_name: name, fields: fields)
          else
            # Variable reference
            AST::VarRef.new(name: name)
          end
        when :LPAREN
          consume(:LPAREN)
          expr = parse_expression
          consume(:RPAREN)
          expr
        when :LBRACE
          # Anonymous record literal
          consume(:LBRACE)
          fields = parse_record_fields
          consume(:RBRACE)
          AST::RecordLit.new(type_name: "record", fields: fields)
        else
          raise "Unexpected token: #{current}"
        end
      end
      
      def parse_args
        args = []
        
        while current.type != :RPAREN
          args << parse_expression
          
          if current.type == :COMMA
            consume(:COMMA)
          else
            break
          end
        end
        
        args
      end
      
      def parse_record_fields
        fields = {}
        
        while current.type != :RBRACE
          field_name = consume(:IDENTIFIER).value
          consume(:COLON)
          value = parse_expression
          
          fields[field_name] = value
          
          if current.type == :COMMA
            consume(:COMMA)
          else
            break
          end
        end
        
        fields
      end
      
      def current
        @tokens[@pos]
      end
      
      def eof?
        @pos >= @tokens.length || current.type == :EOF
      end
      
      def consume(expected_type)
        if eof?
          raise "Unexpected EOF, expected #{expected_type}"
        end
        
        token = current
        if token.type != expected_type
          raise "Expected #{expected_type}, got #{token.type}"
        end
        
        @pos += 1
        token
      end
    end
  end
end
