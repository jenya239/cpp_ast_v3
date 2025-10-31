# frozen_string_literal: true

require_relative "nodes"

module Aurora
  module MidIR
    # Printer - converts Mid IR to human-readable text format
    # Similar to LLVM IR textual representation
    class Printer
      def initialize(indent: "  ")
        @indent = indent
        @output = []
      end

      def print(module_ir)
        @output = []
        print_module(module_ir)
        @output.join("\n")
      end

      private

      def print_module(mod)
        @output << "module #{mod.name}"
        @output << ""

        mod.items.each do |item|
          case item
          when Function
            print_function(item)
            @output << ""
          when TypeDecl
            print_type_decl(item)
          end
        end
      end

      def print_function(func)
        params = func.params.map { |p| "#{p.name}: #{type_str(p.type)}" }.join(", ")
        effects_str = func.effects.empty? ? "" : " #{func.effects.inspect}"

        @output << "fn #{func.name}(#{params}) -> #{type_str(func.ret_type)}#{effects_str}:"

        func.blocks.each do |block|
          print_basic_block(block)
        end
      end

      def print_basic_block(block)
        @output << ""
        @output << "#{block.label}:"

        block.instructions.each do |inst|
          @output << "#{@indent}#{print_instruction(inst)}"
        end

        if block.terminator
          @output << "#{@indent}#{print_terminator(block.terminator)}"
        end
      end

      def print_instruction(inst)
        case inst
        when Assign
          "#{inst.dest} = #{print_expr(inst.value)}"
        when Store
          "store #{print_expr(inst.address)}, #{print_expr(inst.value)}"
        else
          "unknown_instruction"
        end
      end

      def print_terminator(term)
        case term
        when Jump
          "jump #{term.target}"
        when Branch
          "branch #{print_expr(term.condition)}, #{term.true_target}, #{term.false_target}"
        when Return
          if term.value
            "return #{print_expr(term.value)}"
          else
            "return void"
          end
        else
          "unknown_terminator"
        end
      end

      def print_expr(expr)
        case expr
        when Literal
          if expr.value.nil?
            "unit"
          else
            expr.value.inspect
          end
        when Var
          expr.name
        when BinaryOp
          "(#{print_expr(expr.left)} #{expr.op} #{print_expr(expr.right)})"
        when UnaryOp
          "(#{expr.op} #{print_expr(expr.operand)})"
        when Call
          args = expr.args.map { |arg| print_expr(arg) }.join(", ")
          "call #{expr.callee}(#{args})"
        when Member
          "#{print_expr(expr.object)}.#{expr.field}"
        when Load
          "load #{print_expr(expr.address)}"
        when NilClass
          "null"
        else
          "<unknown: #{expr.class.name}>"
        end
      end

      def print_type_decl(type_decl)
        @output << "type #{type_decl.name} = ..."
      end

      def type_str(type)
        return "?" unless type

        case type
        when CoreIR::Type
          type.name.to_s
        when CoreIR::UnitType
          "unit"
        else
          type.class.name.split("::").last
        end
      end
    end
  end
end
