# frozen_string_literal: true

require_relative "../../cpp_ast"
require_relative "../core_ir/nodes"

module Aurora
  module Backend
    class CppLowering
      def initialize
        @type_map = {
          "i32" => "int",
          "f32" => "float", 
          "bool" => "bool",
          "void" => "void"
        }
      end
      
      def lower(core_ir)
        case core_ir
        when CoreIR::Module
          lower_module(core_ir)
        when CoreIR::Func
          lower_function(core_ir)
        when CoreIR::TypeDecl
          lower_type_decl(core_ir)
        else
          raise "Unknown CoreIR node: #{core_ir.class}"
        end
      end
      
      private
      
      def lower_module(module_node)
        items = module_node.items.map { |item| lower(item) }
        CppAst::Nodes::Program.new(statements: items, statement_trailings: Array.new(items.size, ""))
      end
      
      def lower_function(func)
        return_type = map_type(func.ret_type)
        name = func.name
        parameters = func.params.map { |param| "#{map_type(param.type)} #{param.name}" }
        body = lower_expression(func.body)
        
        # Create function body as block
        block_body = CppAst::Nodes::BlockStatement.new(
          statements: [CppAst::Nodes::ReturnStatement.new(expression: body)],
          statement_trailings: [""],
          lbrace_suffix: "",
          rbrace_prefix: ""
        )
        
        CppAst::Nodes::FunctionDeclaration.new(
          return_type: return_type,
          name: name,
          parameters: parameters,
          body: block_body,
          return_type_suffix: " ",
          lparen_suffix: "",
          rparen_suffix: "",
          param_separators: parameters.size > 1 ? Array.new(parameters.size - 1, ", ") : [],
          modifiers_text: "",
          prefix_modifiers: ""
        )
      end
      
      def lower_type_decl(type_decl)
        case type_decl.type
        when CoreIR::RecordType
          lower_record_type(type_decl.name, type_decl.type)
        else
          # For primitive types, we don't need to generate anything
          CppAst::Nodes::Comment.new(text: "// Type alias: #{type_decl.name}")
        end
      end
      
      def lower_record_type(name, record_type)
        # Generate struct declaration
        members = record_type.fields.map do |field|
          field_type = map_type(field[:type])
          CppAst::Nodes::VariableDeclaration.new(
            type: field_type,
            declarators: [field[:name]],
            declarator_separators: [],
            type_suffix: " ",
            prefix_modifiers: ""
          )
        end
        
        CppAst::Nodes::StructDeclaration.new(
          name: name,
          members: members,
          member_trailings: Array.new(members.size, ""),
          struct_suffix: " ",
          name_suffix: " ",
          lbrace_suffix: "",
          rbrace_suffix: "",
          base_classes_text: ""
        )
      end
      
      def lower_expression(expr)
        return CppAst::Nodes::NumberLiteral.new(value: "0") if expr.nil?
        
        case expr
        when CoreIR::LiteralExpr
          lower_literal(expr)
        when CoreIR::VarExpr
          lower_variable(expr)
        when CoreIR::BinaryExpr
          lower_binary(expr)
        when CoreIR::CallExpr
          lower_call(expr)
        when CoreIR::MemberExpr
          lower_member(expr)
        when CoreIR::LetExpr
          lower_let(expr)
        when CoreIR::RecordExpr
          lower_record(expr)
        else
          raise "Unknown expression: #{expr.class}"
        end
      end
      
      def lower_literal(lit)
        case lit.type.name
        when "i32"
          CppAst::Nodes::NumberLiteral.new(value: lit.value.to_s)
        when "f32"
          CppAst::Nodes::NumberLiteral.new(value: lit.value.to_s)
        when "bool"
          CppAst::Nodes::BooleanLiteral.new(value: lit.value)
        else
          CppAst::Nodes::NumberLiteral.new(value: lit.value.to_s)
        end
      end
      
      def lower_variable(var)
        CppAst::Nodes::Identifier.new(name: var.name)
      end
      
      def lower_binary(binary)
        left = lower_expression(binary.left)
        right = lower_expression(binary.right)
        
        CppAst::Nodes::BinaryExpression.new(
          left: left,
          operator: binary.op,
          right: right,
          operator_prefix: " ",
          operator_suffix: " "
        )
      end
      
      def lower_call(call)
        callee = lower_expression(call.callee)
        args = call.args.map { |arg| lower_expression(arg) }
        
        CppAst::Nodes::FunctionCallExpression.new(
          callee: callee,
          arguments: args,
          argument_separators: Array.new(args.size - 1, ", ")
        )
      end
      
      def lower_member(member)
        object = lower_expression(member.object)
        
        CppAst::Nodes::MemberAccessExpression.new(
          object: object,
          operator: ".",
          member_name: member.member
        )
      end
      
      def lower_let(let)
        # For let expressions, we need to create a block with variable declaration
        # and then the body. This is a simplification - in real implementation
        # we'd need to handle this more carefully.
        _value = lower_expression(let.value)
        body = lower_expression(let.body)

        # Create a block that declares the variable and returns the body
        # This is a simplified approach - real implementation would be more complex
        body
      end
      
      def lower_record(record)
        # For record literals, we need to create a constructor call
        # This is simplified - real implementation would handle this properly
        type_name = record.type_name
        fields = record.fields
        
        # Create constructor call with field values
        args = fields.values.map { |value| lower_expression(value) }
        
        CppAst::Nodes::FunctionCallExpression.new(
          callee: CppAst::Nodes::Identifier.new(name: type_name),
          arguments: args,
          argument_separators: Array.new(args.size - 1, ", ")
        )
      end
      
      def map_type(type)
        case type
        when CoreIR::Type
          @type_map[type.name] || type.name
        when CoreIR::RecordType
          type.name
        when CoreIR::FunctionType
          "auto" # Simplified - real implementation would be more complex
        else
          "auto"
        end
      end
    end
  end
end
