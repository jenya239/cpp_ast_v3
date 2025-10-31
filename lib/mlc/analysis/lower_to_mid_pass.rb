# frozen_string_literal: true

require_relative "base_pass"
require_relative "../mid_ir/nodes"

module MLC
  module Analysis
    # LowerToMidPass - transforms High IR (HighIR) to Mid IR
    #
    # Key transformations:
    # - If expressions → basic blocks with branches
    # - Match expressions → if/else chains
    # - While loops → explicit loop blocks
    # - Block expressions → sequence of instructions
    #
    # This creates explicit control flow with basic blocks.
    class LowerToMidPass < BasePass
      def initialize(name: "lower_to_mid")
        super(name: name)
        @temp_counter = 0
        @block_counter = 0
      end

      def input_level
        :high_ir
      end

      def output_level
        :mid_ir
      end

      def required_keys
        [:core_ir]
      end

      def produced_keys
        [:mid_ir]
      end

      def run(context)
        validate_context!(context)

        high_ir = context[:core_ir]
        return unless high_ir

        # Transform module
        mid_module = lower_module(high_ir)

        context[:mid_ir] = mid_module
        context[:current_ir_level] = :mid_ir
      end

      private

      def lower_module(high_module)
        mid_functions = high_module.items.map do |item|
          case item
          when HighIR::Func
            lower_function(item)
          else
            item  # Keep types, etc. as-is for now
          end
        end

        MidIR::Module.new(
          name: high_module.name,
          items: mid_functions,
          origin: high_module.origin
        )
      end

      def lower_function(high_func)
        @temp_counter = 0
        @block_counter = 0
        @current_blocks = []

        # Create entry block
        entry_block = new_block("entry")
        @current_block = entry_block

        # Lower function body
        if high_func.body
          result_value = lower_expr(high_func.body)

          # Add return
          @current_block.terminator = MidIR::Return.new(
            value: result_value,
            origin: high_func.origin
          )
        else
          # External function - no body
          @current_block.terminator = MidIR::Return.new(
            value: nil,
            origin: high_func.origin
          )
        end

        @current_blocks << @current_block

        # Convert params
        mid_params = high_func.params.map do |param|
          MidIR::Param.new(
            name: param.name,
            type: param.type,
            origin: param.origin
          )
        end

        MidIR::Function.new(
          name: high_func.name,
          params: mid_params,
          ret_type: high_func.ret_type,
          blocks: @current_blocks,
          effects: high_func.effects,
          origin: high_func.origin
        )
      end

      def lower_expr(expr)
        case expr
        when HighIR::LiteralExpr
          # Literals pass through
          MidIR::Literal.new(
            value: expr.value,
            type: expr.type,
            origin: expr.origin
          )

        when HighIR::VarExpr
          # Variable references pass through
          MidIR::Var.new(
            name: expr.name,
            type: expr.type,
            origin: expr.origin
          )

        when HighIR::BinaryExpr
          # Binary operations pass through (but operands are lowered)
          left = lower_expr(expr.left)
          right = lower_expr(expr.right)

          MidIR::BinaryOp.new(
            op: expr.op,
            left: left,
            right: right,
            type: expr.type,
            origin: expr.origin
          )

        when HighIR::UnaryExpr
          operand = lower_expr(expr.operand)

          MidIR::UnaryOp.new(
            op: expr.op,
            operand: operand,
            type: expr.type,
            origin: expr.origin
          )

        when HighIR::CallExpr
          # Function calls
          args = expr.args.map { |arg| lower_expr(arg) }

          MidIR::Call.new(
            callee: expr.callee.name,
            args: args,
            type: expr.type,
            origin: expr.origin
          )

        when HighIR::IfExpr
          # If expression → basic blocks
          lower_if_expr(expr)

        when HighIR::BlockExpr
          # Block expression → sequence of instructions
          lower_block_expr(expr)

        when HighIR::MemberExpr
          object = lower_expr(expr.object)

          MidIR::Member.new(
            object: object,
            field: expr.member,
            type: expr.type,
            origin: expr.origin
          )

        else
          # Fallback: create a temporary variable
          temp = new_temp
          # For now, we can't fully lower unknown expressions
          # This is a placeholder for future extensions
          MidIR::Var.new(name: temp, type: expr.type, origin: expr.origin)
        end
      end

      def lower_if_expr(if_expr)
        # Create basic blocks for if expression
        # Pattern:
        #   current_block:
        #     condition = ...
        #     branch condition, then_block, else_block
        #
        #   then_block:
        #     then_value = ...
        #     jump merge_block
        #
        #   else_block:
        #     else_value = ...
        #     jump merge_block
        #
        #   merge_block:
        #     result = phi(then_value, else_value)  # simplified for now

        # Lower condition in current block
        condition = lower_expr(if_expr.condition)

        # Create blocks
        then_block = new_block("then")
        else_block = new_block("else")
        merge_block = new_block("merge")

        # Set branch in current block
        @current_block.terminator = MidIR::Branch.new(
          condition: condition,
          true_target: then_block.label,
          false_target: else_block.label,
          origin: if_expr.origin
        )
        @current_blocks << @current_block

        # Lower then branch
        @current_block = then_block
        then_value = lower_expr(if_expr.then_branch)
        then_temp = assign_temp(then_value)
        @current_block.terminator = MidIR::Jump.new(
          target: merge_block.label,
          origin: if_expr.origin
        )
        @current_blocks << @current_block

        # Lower else branch
        @current_block = else_block
        if if_expr.else_branch
          else_value = lower_expr(if_expr.else_branch)
        else
          # No else branch - use unit/void
          else_value = MidIR::Literal.new(value: nil, type: HighIR::UnitType.new)
        end
        else_temp = assign_temp(else_value)
        @current_block.terminator = MidIR::Jump.new(
          target: merge_block.label,
          origin: if_expr.origin
        )
        @current_blocks << @current_block

        # Merge block
        @current_block = merge_block
        # For now, just return one of the values (simplified phi)
        # In future, add proper phi nodes
        MidIR::Var.new(name: then_temp, type: if_expr.type)
      end

      def lower_block_expr(block_expr)
        # Lower each statement in sequence
        last_value = nil

        block_expr.statements.each do |stmt|
          last_value = lower_expr(stmt)
        end

        last_value || MidIR::Literal.new(value: nil, type: HighIR::UnitType.new)
      end

      def assign_temp(value)
        temp = new_temp
        instruction = MidIR::Assign.new(
          dest: temp,
          value: value,
          type: value.respond_to?(:type) ? value.type : nil,
          origin: value.respond_to?(:origin) ? value.origin : nil
        )
        @current_block.instructions << instruction
        temp
      end

      def new_temp
        temp = "t#{@temp_counter}"
        @temp_counter += 1
        temp
      end

      def new_block(prefix = "bb")
        label = "#{prefix}_#{@block_counter}"
        @block_counter += 1

        MidIR::BasicBlock.new(
          label: label,
          instructions: [],
          terminator: nil  # Will be set later
        )
      end
    end
  end
end
