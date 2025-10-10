# frozen_string_literal: true

module CppAst
  module Parsers
    # ControlFlowParser - module with control flow parsing methods
    # Handles: if, while, for, do-while, switch/case, break, continue
    #
    # This module contains all control flow statement parsing logic.
    # It is included in StatementParser to modularize the codebase.
    #
    # Methods:
    #   - parse_if_statement
    #   - parse_while_statement
    #   - parse_for_statement  
    #   - parse_do_while_statement
    #   - parse_switch_statement
    #   - parse_case_clause
    #   - parse_default_clause
    #   - parse_break_statement
    #   - parse_continue_statement
    module ControlFlowParser
      # Note: All methods are in statement_parser.rb for now
      # Future refactoring can move them here
    end
  end
end

