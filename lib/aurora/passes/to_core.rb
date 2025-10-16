# frozen_string_literal: true

require_relative "../core_ir/nodes"
require_relative "../core_ir/builder"

module Aurora
  module Passes
    class ToCore
      def initialize
        @type_table = {}
        @function_table = {}
      end
      
      def transform(ast)
        case ast
        when AST::Program
          transform_program(ast)
        when AST::FuncDecl
          transform_function(ast)
        when AST::TypeDecl
          transform_type_decl(ast)
        else
          raise "Unknown AST node: #{ast.class}"
        end
      end
      
      private
      
      def transform_program(program)
        items = []
        
        program.declarations.each do |decl|
          case decl
          when AST::TypeDecl
            type_decl = transform_type_decl(decl)
            items << type_decl
            @type_table[decl.name] = type_decl.type
          when AST::FuncDecl
            func = transform_function(decl)
            items << func
            @function_table[decl.name] = func
          end
        end
        
        CoreIR::Module.new(name: "main", items: items)
      end
      
      def transform_type_decl(decl)
        type = transform_type(decl.type)
        CoreIR::TypeDecl.new(name: decl.name, type: type)
      end
      
      def transform_function(func)
        params = func.params.map { |param| transform_param(param) }
        ret_type = transform_type(func.ret_type)
        body = transform_expression(func.body)
        
        CoreIR::Func.new(
          name: func.name,
          params: params,
          ret_type: ret_type,
          body: body,
          effects: infer_effects(body)
        )
      end
      
      def transform_param(param)
        type = transform_type(param.type)
        CoreIR::Param.new(name: param.name, type: type)
      end
      
      def transform_type(type)
        case type
        when AST::PrimType
          CoreIR::Builder.primitive_type(type.name)
        when AST::RecordType
          fields = type.fields.map { |field| {name: field[:name], type: transform_type(field[:type])} }
          CoreIR::Builder.record_type(type.name, fields)
        else
          raise "Unknown type: #{type.class}"
        end
      end
      
      def transform_expression(expr)
        case expr
        when AST::IntLit
          type = CoreIR::Builder.primitive_type("i32")
          CoreIR::Builder.literal(expr.value, type)
        when AST::FloatLit
          type = CoreIR::Builder.primitive_type("f32")
          CoreIR::Builder.literal(expr.value, type)
        when AST::VarRef
          type = infer_type(expr.name)
          CoreIR::Builder.var(expr.name, type)
        when AST::BinaryOp
          left = transform_expression(expr.left)
          right = transform_expression(expr.right)
          type = infer_binary_type(expr.op, left.type, right.type)
          CoreIR::Builder.binary(expr.op, left, right, type)
        when AST::Call
          callee = transform_expression(expr.callee)
          args = expr.args.map { |arg| transform_expression(arg) }
          type = infer_call_type(callee, args)
          CoreIR::Builder.call(callee, args, type)
        when AST::MemberAccess
          object = transform_expression(expr.object)
          type = infer_member_type(object.type, expr.member)
          CoreIR::Builder.member(object, expr.member, type)
        when AST::Let
          value = transform_expression(expr.value)
          body = transform_expression(expr.body)
          type = body.type
          CoreIR::Builder.let(expr.name, value, body, type)
        when AST::RecordLit
          type = @type_table[expr.type_name]
          fields = expr.fields.transform_values { |value| transform_expression(value) }
          CoreIR::Builder.record(expr.type_name, fields, type)
        when AST::IfExpr
          condition = transform_expression(expr.condition)
          then_branch = transform_expression(expr.then_branch)
          else_branch = expr.else_branch ? transform_expression(expr.else_branch) : nil
          type = then_branch.type  # Type inference: result type is from then branch
          CoreIR::Builder.if_expr(condition, then_branch, else_branch, type)
        else
          raise "Unknown expression: #{expr.class}"
        end
      end
      
      def infer_type(name)
        # Simple type inference - in real implementation would be more sophisticated
        case name
        when "sqrt"
          params = [CoreIR::Builder.primitive_type("f32")]
          ret_type = CoreIR::Builder.primitive_type("f32")
          CoreIR::Builder.function_type(params, ret_type)
        else
          # Default to i32 for now
          CoreIR::Builder.primitive_type("i32")
        end
      end
      
      def infer_binary_type(op, left_type, right_type)
        case op
        when "+", "-", "*", "/", "%"
          # Numeric operations
          if left_type.name == "f32" || right_type.name == "f32"
            CoreIR::Builder.primitive_type("f32")
          else
            CoreIR::Builder.primitive_type("i32")
          end
        when "==", "!=", "<", ">", "<=", ">="
          CoreIR::Builder.primitive_type("bool")
        else
          left_type
        end
      end
      
      def infer_call_type(callee, args)
        # Simple inference - in real implementation would check function signatures
        case callee
        when CoreIR::VarExpr
          # Simple function call like sqrt(x)
          if callee.name == "sqrt"
            CoreIR::Builder.primitive_type("f32")
          else
            CoreIR::Builder.primitive_type("i32")
          end
        when CoreIR::MemberExpr
          # Method call like (expr).sqrt()
          if callee.member == "sqrt"
            CoreIR::Builder.primitive_type("f32")
          else
            CoreIR::Builder.primitive_type("i32")
          end
        else
          CoreIR::Builder.primitive_type("i32")
        end
      end
      
      def infer_member_type(object_type, member)
        # Simple inference for record types
        if object_type.record?
          field = object_type.fields.find { |f| f[:name] == member }
          field ? field[:type] : CoreIR::Builder.primitive_type("i32")
        else
          CoreIR::Builder.primitive_type("i32")
        end
      end
      
      def infer_effects(body)
        # Simple effect inference
        effects = []
        
        # Check if function is pure (no side effects)
        if is_pure_expression(body)
          effects << :constexpr
        end
        
        effects << :noexcept
        
        effects
      end
      
      def is_pure_expression(expr)
        case expr
        when CoreIR::LiteralExpr, CoreIR::VarExpr
          true
        when CoreIR::BinaryExpr
          is_pure_expression(expr.left) && is_pure_expression(expr.right)
        when CoreIR::CallExpr
          # Assume all calls are pure for now
          true
        when CoreIR::MemberExpr
          is_pure_expression(expr.object)
        when CoreIR::LetExpr
          is_pure_expression(expr.value) && is_pure_expression(expr.body)
        when CoreIR::RecordExpr
          expr.fields.values.all? { |field| is_pure_expression(field) }
        else
          false
        end
      end
    end
  end
end
