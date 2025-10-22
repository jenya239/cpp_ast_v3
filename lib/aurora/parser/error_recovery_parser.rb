# frozen_string_literal: true

require_relative "parser"
require_relative "../error_handling/enhanced_errors"

module Aurora
  module Parser
    # Parser with error recovery and multiple error reporting
    class ErrorRecoveryParser < Parser
      def initialize(source, filename: nil)
        super(source, filename: filename)
        @errors = []
        @recovery_points = []
      end
      
      def parse
        @errors.clear
        @recovery_points.clear
        
        begin
          result = parse_program_with_recovery
          if @errors.any?
            raise MultipleErrors.new(@errors)
          end
          result
        rescue StandardError => e
          if @errors.any?
            raise MultipleErrors.new(@errors)
          else
            raise e
          end
        end
      end
      
      private
      
      def parse_program_with_recovery
        module_decl = nil
        imports = []
        declarations = []
        
        # Parse optional module declaration
        if current.type == :MODULE
          begin
            module_decl = parse_module_decl
          rescue StandardError => e
            add_error(e, "Failed to parse module declaration")
            recover_to_next_declaration
          end
        end
        
        # Parse imports with error recovery
        while current.type == :IMPORT
          begin
            imports << parse_import_decl
          rescue StandardError => e
            add_error(e, "Failed to parse import declaration")
            recover_to_next_declaration
          end
        end
        
        # Parse declarations with error recovery
        while !eof?
          begin
            case current.type
            when :EXPORT
              consume(:EXPORT)
              case current.type
              when :FN
                func = parse_function
                func.exported = true
                declarations << func
              when :TYPE
                type_decl = parse_type_decl
                type_decl.exported = true
                declarations << type_decl
              else
                add_syntax_error("Expected function or type declaration after export")
                recover_to_next_declaration
              end
            when :FN
              declarations << parse_function
            when :TYPE
              declarations << parse_type_decl
            else
              add_syntax_error("Unexpected token: #{current.type}")
              recover_to_next_declaration
            end
          rescue StandardError => e
            add_error(e, "Failed to parse declaration")
            recover_to_next_declaration
          end
        end
        
        AST::Program.new(
          module_decl: module_decl,
          imports: imports,
          declarations: declarations
        )
      end
      
      def recover_to_next_declaration
        # Skip tokens until we find a declaration boundary
        while !eof? && !declaration_start?
          skip_token
        end
      end
      
      def declaration_start?
        [:FN, :TYPE, :IMPORT, :EXPORT].include?(current.type)
      end
      
      def add_error(original_error, context)
        error = case original_error
        when Aurora::AuroraSyntaxError
          Aurora::AuroraSyntaxError.new(
            original_error.message,
            location: current_location,
            suggestion: suggest_fix(original_error),
            context: context
          )
        when Aurora::AuroraTypeError
          Aurora::AuroraTypeError.new(
            original_error.message,
            location: current_location,
            suggestion: suggest_type_fix(original_error),
            context: context
          )
        else
          Aurora::EnhancedError.new(
            original_error.message,
            location: current_location,
            suggestion: "Check your syntax and try again",
            context: context
          )
        end
        
        @errors << error
      end
      
      def add_syntax_error(message)
        error = Aurora::AuroraSyntaxError.new(
          message,
          location: current_location,
          suggestion: suggest_syntax_fix,
          context: "At token: #{current.value || current.type}"
        )
        @errors << error
      end
      
      def current_location
        "line #{current.line || 'unknown'}, column #{current.column || 'unknown'}"
      end
      
      def suggest_fix(error)
        case error.message
        when /unexpected token/
          "Check for missing semicolons, parentheses, or braces"
        when /expected.*got/
          "Check your syntax - you may have a typo or missing token"
        when /unterminated/
          "Check for matching quotes, parentheses, or braces"
        else
          "Review the syntax rules for this construct"
        end
      end
      
      def suggest_type_fix(error)
        case error.message
        when /type mismatch/
          "Check that your variable types match their usage"
        when /undefined variable/
          "Make sure the variable is declared before use"
        when /incompatible types/
          "Check that you're using compatible types in this operation"
        else
          "Review the type system rules"
        end
      end
      
      def suggest_syntax_fix
        case current.type
        when :IDENTIFIER
          "Check if this identifier is properly declared"
        when :OPERATOR
          "Check if this operator is used correctly"
        when :LPAREN, :RPAREN
          "Check for matching parentheses"
        when :LBRACE, :RBRACE
          "Check for matching braces"
        else
          "Check the syntax rules for this token"
        end
      end
    end
    
    # Multiple errors container
    class MultipleErrors < StandardError
      attr_reader :errors
      
      def initialize(errors)
        @errors = errors
        super("Found #{errors.length} error(s)")
      end
      
      def formatted_message
        lines = ["Found #{@errors.length} error(s):", ""]
        
        @errors.each_with_index do |error, index|
          lines << "#{index + 1}. #{error.formatted_message}"
          lines << ""
        end
        
        lines.join("\n")
      end
    end
  end
end
