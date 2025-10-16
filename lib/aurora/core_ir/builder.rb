# frozen_string_literal: true

require_relative "nodes"

module Aurora
  module CoreIR
    # Builder helpers for CoreIR
    class Builder
      def self.primitive_type(name, origin: nil)
        Type.new(kind: :prim, name: name, origin: origin)
      end
      
      def self.record_type(name, fields, origin: nil)
        RecordType.new(name: name, fields: fields, origin: origin)
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
      
      def self.var(name, type, origin: nil)
        VarExpr.new(name: name, type: type, origin: origin)
      end
      
      def self.binary(op, left, right, type, origin: nil)
        BinaryExpr.new(op: op, left: left, right: right, type: type, origin: origin)
      end
      
      def self.call(callee, args, type, origin: nil)
        CallExpr.new(callee: callee, args: args, type: type, origin: origin)
      end
      
      def self.member(object, member, type, origin: nil)
        MemberExpr.new(object: object, member: member, type: type, origin: origin)
      end
      
      def self.let(name, value, body, type, origin: nil)
        LetExpr.new(name: name, value: value, body: body, type: type, origin: origin)
      end
      
      def self.record(type_name, fields, type, origin: nil)
        RecordExpr.new(type_name: type_name, fields: fields, type: type, origin: origin)
      end

      def self.if_expr(condition, then_branch, else_branch, type, origin: nil)
        IfExpr.new(condition: condition, then_branch: then_branch, else_branch: else_branch, type: type, origin: origin)
      end

      def self.block(stmts, origin: nil)
        Block.new(stmts: stmts, origin: origin)
      end
      
      def self.return_stmt(expr, origin: nil)
        Return.new(expr: expr, origin: origin)
      end
      
      def self.type_decl(name, type, origin: nil)
        TypeDecl.new(name: name, type: type, origin: origin)
      end
    end
  end
end
