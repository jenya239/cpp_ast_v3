# frozen_string_literal: true

module CppAst
  module Builder
    module ExprBuilder
      # Expression node with operator overloading
      class ExprNode
        attr_reader :node
        
        def initialize(node)
          @node = node
        end
        
        # Delegate attribute access to the underlying node
        def method_missing(method_name, *args, &block)
          if @node.respond_to?(method_name)
            @node.send(method_name, *args, &block)
          else
            super
          end
        end
        
        def respond_to_missing?(method_name, include_private = false)
          @node.respond_to?(method_name, include_private) || super
        end
        
        # Binary operators
        def +(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: "+",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        def -(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: "-",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        def *(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: "*",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        def /(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: "/",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        def %(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: "%",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        def ==(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: "==",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        def !=(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: "!=",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        def <(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: "<",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        def <=(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: "<=",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        def >(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: ">",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        def >=(other)
          ExprNode.new(Nodes::BinaryExpression.new(
            left: @node,
            operator: ">=",
            right: other.node,
            operator_prefix: " ",
            operator_suffix: " "
          ))
        end
        
        # Unary operators
        def -@
          ExprNode.new(Nodes::UnaryExpression.new(
            operator: "-",
            operand: @node,
            prefix: true
          ))
        end
        
        def !
          ExprNode.new(Nodes::UnaryExpression.new(
            operator: "!",
            operand: @node,
            prefix: true
          ))
        end
        
        # Postfix operators
        def increment
          ExprNode.new(Nodes::UnaryExpression.new(
            operator: "++",
            operand: @node,
            prefix: false
          ))
        end
        
        def decrement
          ExprNode.new(Nodes::UnaryExpression.new(
            operator: "--",
            operand: @node,
            prefix: false
          ))
        end
        
        # Method calls
        def call(method_name, *args)
          ExprNode.new(Nodes::FunctionCallExpression.new(
            callee: Nodes::MemberAccessExpression.new(
              object: @node,
              operator: ".",
              member: method_name.to_s
            ),
            arguments: args.map(&:node),
            argument_separators: args.size > 1 ? Array.new(args.size - 1, ", ") : []
          ))
        end
        
        # Member access
        def [](index)
          ExprNode.new(Nodes::ArrayAccessExpression.new(
            array: @node,
            index: index.node
          ))
        end
        
        # Member access with dot
        def member(field_name)
          ExprNode.new(Nodes::MemberAccessExpression.new(
            object: @node,
            operator: ".",
            member: field_name.to_s
          ))
        end
        
        # Pipe operator
        def pipe(method_name, *args)
          call(method_name, *args)
        end
        
        # Assignment
        def assign(value)
          ExprNode.new(Nodes::AssignmentExpression.new(
            left: @node,
            operator: "=",
            right: value.node
          ))
        end
        
        # Convert to underlying node
        def to_node
          @node
        end
        
        # For compatibility with existing DSL
        def to_source
          @node.to_source
        end
      end
    
    # Expression DSL methods
    module Expressions
      # Identifier
      def id(name)
        ExprNode.new(Nodes::Identifier.new(name: name.to_s))
      end
      
      # Literals
      def int(value)
        ExprNode.new(Nodes::NumberLiteral.new(value: value.to_s))
      end
      
      def float(value)
        ExprNode.new(Nodes::NumberLiteral.new(value: value.to_s))
      end
      
      def string(value)
        ExprNode.new(Nodes::StringLiteral.new(value: value))
      end
      
      def bool(value)
        ExprNode.new(Nodes::BooleanLiteral.new(value: value))
      end
      
      def char(value)
        ExprNode.new(Nodes::CharLiteral.new(value: value))
      end
      
      # Function call
      def call(callee, *args)
        # Handle Symbol callee
        callee_node = callee.is_a?(Symbol) ? Nodes::Identifier.new(name: callee.to_s) : callee.node
        
        ExprNode.new(Nodes::FunctionCallExpression.new(
          callee: callee_node,
          arguments: args.map { |arg| arg.respond_to?(:node) ? arg.node : arg },
          argument_separators: args.size > 1 ? Array.new(args.size - 1, ", ") : []
        ))
      end
      
      # Member access
      def member(object, field_name)
        ExprNode.new(Nodes::MemberAccessExpression.new(
          object: object.node,
          operator: ".",
          member: field_name.to_s
        ))
      end
      
      # Array access
      def array_access(array, index)
        ExprNode.new(Nodes::ArrayAccessExpression.new(
          array: array.node,
          index: index.node
        ))
      end
      
      # Dereference
      def deref(expr)
        ExprNode.new(Nodes::UnaryExpression.new(
          operator: "*",
          operand: expr.node,
          prefix: true
        ))
      end
      
      # Address of
      def address_of(expr)
        ExprNode.new(Nodes::UnaryExpression.new(
          operator: "&",
          operand: expr.node,
          prefix: true
        ))
      end
      
      # Cast
      def cast(type, expr)
        ExprNode.new(Nodes::CastExpression.new(
          type: type.to_cpp_type,
          expression: expr.node
        ))
      end
      
      # Ternary operator
      def ternary(condition, true_expr, false_expr)
        ExprNode.new(Nodes::TernaryExpression.new(
          condition: condition.node,
          true_expression: true_expr.node,
          false_expression: false_expr.node
        ))
      end
      
      # Sizeof
      def sizeof(type_or_expr)
        if type_or_expr.respond_to?(:to_cpp_type)
          ExprNode.new(Nodes::SizeofExpression.new(expression: type_or_expr.to_cpp_type))
        else
          ExprNode.new(Nodes::SizeofExpression.new(expression: type_or_expr.node))
        end
      end
      
      # New/Delete
      def new(type, *args)
        ExprNode.new(Nodes::NewExpression.new(
          type: type.to_cpp_type,
          arguments: args.map(&:node)
        ))
      end
      
      def delete(expr)
        ExprNode.new(Nodes::DeleteExpression.new(expression: expr.node))
      end
      
      # Lambda
      def lambda_expr(params, body)
        ExprNode.new(Nodes::LambdaExpression.new(
          parameters: params,
          body: body.node
        ))
      end
      
      # No alias to avoid conflict with TypesDSL::lambda
    end
    
    # Include Expressions module in DSL
    def self.included(base)
      base.include Expressions
    end
    
    # Also include Expressions when ExprBuilder is included
    include Expressions
  end
end
end
