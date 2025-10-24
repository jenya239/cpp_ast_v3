# frozen_string_literal: true

require_relative "nodes"

module Aurora
  module CoreIR
    # Builder helpers for CoreIR
    class Builder
      def self.primitive_type(name, origin: nil)
        Type.new(kind: :prim, name: name, origin: origin)
      end

      def self.unit_type(origin: nil)
        UnitType.new(origin: origin)
      end

      def self.opaque_type(name, origin: nil)
        OpaqueType.new(name: name, origin: origin)
      end

      def self.record_type(name, fields, origin: nil)
        RecordType.new(name: name, fields: fields, origin: origin)
      end

      def self.sum_type(name, variants, origin: nil)
        SumType.new(name: name, variants: variants, origin: origin)
      end

      def self.function_type(params, ret_type, origin: nil)
        FunctionType.new(params: params, ret_type: ret_type, origin: origin)
      end
      
      def self.param(name, type, origin: nil)
        Param.new(name: name, type: type, origin: origin)
      end
      
      def self.func(name, params, ret_type, body, effects: [], origin: nil)
        Func.new(name: name, params: params, ret_type: ret_type, body: body, effects: effects, origin: origin)
      end
      
      def self.literal(value, type, origin: nil)
        LiteralExpr.new(value: value, type: type, origin: origin)
      end

      def self.unit_literal(origin: nil)
        UnitLiteral.new(origin: origin)
      end

      def self.regex(pattern, flags, type, origin: nil)
        RegexExpr.new(pattern: pattern, flags: flags, type: type, origin: origin)
      end

      def self.var(name, type, origin: nil)
        VarExpr.new(name: name, type: type, origin: origin)
      end

      # Alias for var
      def self.var_expr(name, type, origin: nil)
        var(name, type, origin: origin)
      end

      def self.binary(op, left, right, type, origin: nil)
        BinaryExpr.new(op: op, left: left, right: right, type: type, origin: origin)
      end

      # Alias for binary
      def self.binary_expr(op, left, right, type, origin: nil)
        binary(op, left, right, type, origin: origin)
      end

      def self.unary(op, operand, type, origin: nil)
        UnaryExpr.new(op: op, operand: operand, type: type, origin: origin)
      end

      def self.unary_expr(op, operand, type, origin: nil)
        unary(op, operand, type, origin: origin)
      end

      def self.call(callee, args, type, origin: nil)
        CallExpr.new(callee: callee, args: args, type: type, origin: origin)
      end

      # Alias for call
      def self.call_expr(callee, args, type, origin: nil)
        call(callee, args, type, origin: origin)
      end
      
      def self.member(object, member, type, origin: nil)
        MemberExpr.new(object: object, member: member, type: type, origin: origin)
      end
      
      def self.record(type_name, fields, type, origin: nil)
        RecordExpr.new(type_name: type_name, fields: fields, type: type, origin: origin)
      end

      def self.if_expr(condition, then_branch, else_branch, type, origin: nil)
        IfExpr.new(condition: condition, then_branch: then_branch, else_branch: else_branch, type: type, origin: origin)
      end

      def self.match_expr(scrutinee, arms, type, origin: nil)
        MatchExpr.new(scrutinee: scrutinee, arms: arms, type: type, origin: origin)
      end

      def self.block(stmts, origin: nil)
        Block.new(stmts: stmts, origin: origin)
      end
      
      def self.return_stmt(expr = nil, origin: nil)
        Return.new(expr: expr, origin: origin)
      end

      def self.expr_statement(expression, origin: nil)
        ExprStatement.new(expression: expression, origin: origin)
      end

      def self.variable_decl_stmt(name, type, value, mutable: false, origin: nil)
        VariableDeclStmt.new(name: name, type: type, value: value, mutable: mutable, origin: origin)
      end

      def self.assignment_stmt(target, value, origin: nil)
        AssignmentStmt.new(target: target, value: value, origin: origin)
      end

      def self.for_stmt(var_name, var_type, iterable, body, origin: nil)
        ForStmt.new(var_name: var_name, var_type: var_type, iterable: iterable, body: body, origin: origin)
      end

      def self.if_stmt(condition, then_body, else_body = nil, origin: nil)
        IfStmt.new(condition: condition, then_body: then_body, else_body: else_body, origin: origin)
      end

      def self.while_stmt(condition, body, origin: nil)
        WhileStmt.new(condition: condition, body: body, origin: origin)
      end

      def self.break_stmt(origin: nil)
        BreakStmt.new(origin: origin)
      end

      def self.continue_stmt(origin: nil)
        ContinueStmt.new(origin: origin)
      end

      def self.for_loop_expr(var_name, var_type, iterable, body, origin: nil)
        ForLoopExpr.new(var_name: var_name, var_type: var_type, iterable: iterable, body: body, origin: origin)
      end

      def self.while_loop_expr(condition, body, origin: nil)
        WhileLoopExpr.new(condition: condition, body: body, origin: origin)
      end
      
      def self.type_decl(name, type, origin: nil)
        TypeDecl.new(name: name, type: type, origin: origin)
      end

      def self.module_node(items, name: nil, imports: [], origin: nil)
        Module.new(name: name, items: items, imports: imports, origin: origin)
      end

      def self.block_expr(statements, result, type, origin: nil)
        BlockExpr.new(statements: statements, result: result, type: type, origin: origin)
      end
    end
  end
end
