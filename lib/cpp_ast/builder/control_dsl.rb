# frozen_string_literal: true

module CppAst
  module Builder
    module ControlDSL
      # Control flow DSL methods
      module ControlFlow
        # If statement with block syntax
        def if_(condition, &block)
          then_block = block_given? ? block.call : nil
          IfStatementBuilder.new(condition, then_block)
        end
        
        # While loop with block syntax
        def while_(condition, &block)
          body = block_given? ? block.call : nil
          WhileStatementBuilder.new(condition, body)
        end
        
        # For loop with block syntax
        def for_(init, condition, increment, body = nil, &block)
          actual_body = block_given? ? block.call : body
          ForStatementBuilder.new(init, condition, increment, actual_body)
        end
        
        # For loop with 4 parameters (init, condition, increment, body)
        def for_loop(init, condition, increment, body, &block)
          actual_body = block_given? ? block.call : body
          ForStatementBuilder.new(init, condition, increment, actual_body)
        end
        
        # Range-based for loop
        def for_range(var, range, &block)
          body = block_given? ? block.call : nil
          RangeForStatementBuilder.new(var, range, body)
        end
        
        # Switch statement
        def switch_(expression, &block)
          cases = block_given? ? block.call : []
          SwitchStatementBuilder.new(expression, cases)
        end
        
        # Case clause
        def case_(value, &block)
          body = block_given? ? block.call : nil
          CaseClauseBuilder.new(value, body)
        end
        
        # Default clause
        def default_(&block)
          body = block_given? ? block.call : nil
          DefaultClauseBuilder.new(body)
        end
        
        # Break statement
        def break_
          Nodes::BreakStatement.new
        end
        
        # Continue statement
        def continue_
          Nodes::ContinueStatement.new
        end
        
        # Return statement
        def ret(expression = nil)
          if expression
            Nodes::ReturnStatement.new(expression: expression.node)
          else
            Nodes::ReturnStatement.new(expression: nil)
          end
        end
        
        # Throw statement
        def throw_(expression)
          Nodes::ThrowStatement.new(expression: expression.node)
        end
        
        # Try-catch block
        def try_(&block)
          body = block_given? ? block.call : nil
          TryStatementBuilder.new(body)
        end
        
        # Catch clause
        def catch_(type, var, &block)
          body = block_given? ? block.call : nil
          CatchClauseBuilder.new(type, var, body)
        end
      end
      
      # If statement builder
      class IfStatementBuilder
        def initialize(condition, then_block)
          @condition = condition
          @then_block = then_block
          @elsif_clauses = []
          @else_block = nil
        end
        
        def elsif(condition, &block)
          @elsif_clauses << { condition: condition, block: block.call }
          self
        end
        
        def else_(&block)
          @else_block = block.call
          self
        end
        
        def to_node
          # Build nested if statements for elsif
          result = Nodes::IfStatement.new(
            condition: @condition.node,
            then_statement: @then_block.node,
            else_statement: build_else_chain
          )
          result
        end
        
        # Alias for backward compatibility
        def node
          to_node
        end
        
        private
        
        def build_else_chain
          return @else_block.node if @else_block
          return nil if @elsif_clauses.empty?
          
          elsif_clause = @elsif_clauses.first
          remaining = @elsif_clauses[1..-1]
          
          if remaining.empty?
            Nodes::IfStatement.new(
              condition: elsif_clause[:condition].node,
              then_statement: elsif_clause[:block].node,
              else_statement: @else_block&.node
            )
          else
            # Recursively build nested if statements
            inner = build_else_chain_for(remaining)
            Nodes::IfStatement.new(
              condition: elsif_clause[:condition].node,
              then_statement: elsif_clause[:block].node,
              else_statement: inner
            )
          end
        end
        
        def build_else_chain_for(clauses)
          return @else_block.node if @else_block && clauses.empty?
          return nil if clauses.empty?
          
          clause = clauses.first
          remaining = clauses[1..-1]
          
          if remaining.empty?
            Nodes::IfStatement.new(
              condition: clause[:condition].node,
              then_statement: clause[:block].node,
              else_statement: @else_block&.node
            )
          else
            inner = build_else_chain_for(remaining)
            Nodes::IfStatement.new(
              condition: clause[:condition].node,
              then_statement: clause[:block].node,
              else_statement: inner
            )
          end
        end
      end
      
      # While statement builder
      class WhileStatementBuilder
        def initialize(condition, body)
          @condition = condition
          @body = body
        end
        
        def to_node
          Nodes::WhileStatement.new(
            condition: @condition.node,
            body: @body.node
          )
        end
      end
      
      # For statement builder
      class ForStatementBuilder
        def initialize(init, condition, increment, body)
          @init = init
          @condition = condition
          @increment = increment
          @body = body
        end
        
        def to_node
          Nodes::ForStatement.new(
            init: @init.node,
            condition: @condition.node,
            increment: @increment.node,
            body: @body.node
          )
        end
      end
      
      # Range-based for statement builder
      class RangeForStatementBuilder
        def initialize(var, range, body)
          @var = var
          @range = range
          @body = body
        end
        
        def to_node
          # Handle symbol variables
          var_node = @var.is_a?(Symbol) ? Nodes::Identifier.new(name: @var.to_s) : @var.node
          range_node = @range.respond_to?(:node) ? @range.node : @range
          body_node = @body.respond_to?(:node) ? @body.node : @body
          
          Nodes::RangeForStatement.new(
            variable: var_node,
            container: range_node,
            body: body_node
          )
        end
      end
      
      # Switch statement builder
      class SwitchStatementBuilder
        def initialize(expression, cases)
          @expression = expression
          @cases = cases
        end
        
        def to_node
          Nodes::SwitchStatement.new(
            expression: @expression.node,
            cases: @cases.map(&:to_node)
          )
        end
      end
      
      # Case clause builder
      class CaseClauseBuilder
        def initialize(value, body)
          @value = value
          @body = body
        end
        
        def to_node
          Nodes::CaseClause.new(
            value: @value.node,
            statements: [@body.node],
            statement_trailings: []
          )
        end
      end
      
      # Default clause builder
      class DefaultClauseBuilder
        def initialize(body)
          @body = body
        end
        
        def to_node
          Nodes::DefaultClause.new(
            leading_trivia: "",
            statements: @body ? [@body.node] : [],
            statement_trailings: []
          )
        end
      end
      
      # Try statement builder
      class TryStatementBuilder
        def initialize(body)
          @body = body
          @catch_clauses = []
        end
        
        def catch(type, var, &block)
          @catch_clauses << { type: type, var: var, block: block.call }
          self
        end
        
        def to_node
          Nodes::TryStatement.new(
            leading_trivia: "",
            try_block: @body.node,
            catch_clauses: @catch_clauses.map do |clause|
              Nodes::CatchClause.new(
                leading_trivia: "",
                type: clause[:type].to_cpp_type,
                variable: clause[:var].node,
                body: clause[:block].node
              )
            end
          )
        end
      end
      
      # Catch clause builder
      class CatchClauseBuilder
        def initialize(type, var, body)
          @type = type
          @var = var
          @body = body
        end
        
        def to_node
          Nodes::CatchClause.new(
            type: @type.to_cpp_type,
            variable: @var.node,
            body: @body.node
          )
        end
      end
      
      # Include ControlFlow module in DSL
      def self.included(base)
        base.include ControlFlow
      end
      
      # Else builder
      class ElseBuilder
        def initialize
        end
        
        def to_node
          Nodes::ElseClause.new
        end
      end
    end
  end
end
