# frozen_string_literal: true

module Aurora
  module CoreIR
    # Base node with origin tracking
    class Node
      attr_reader :origin
      
      def initialize(origin: nil)
        @origin = origin
      end
    end
    
    # Types
    class Type < Node
      attr_reader :kind, :name
      
      def initialize(kind:, name:, origin: nil)
        super(origin: origin)
        @kind = kind  # :prim/:record/:func
        @name = name
      end
      
      def primitive?
        @kind == :prim
      end
      
      def record?
        @kind == :record
      end
      
      def function?
        @kind == :func
      end
    end
    
    # Record type with fields
    class RecordType < Type
      attr_reader :fields
      
      def initialize(name:, fields:, origin: nil)
        super(kind: :record, name: name, origin: origin)
        @fields = fields  # Array of {name: String, type: Type}
      end
    end
    
    # Function type
    class FunctionType < Type
      attr_reader :params, :ret_type
      
      def initialize(params:, ret_type:, origin: nil)
        super(kind: :func, name: "function", origin: origin)
        @params = params  # Array of {name: String, type: Type}
        @ret_type = ret_type
      end
    end
    
    # Modules
    class Module < Node
      attr_reader :name, :items
      
      def initialize(name:, items:, origin: nil)
        super(origin: origin)
        @name = name
        @items = items  # Array of declarations
      end
    end
    
    # Function declaration
    class Func < Node
      attr_reader :name, :params, :ret_type, :body, :effects
      
      def initialize(name:, params:, ret_type:, body:, effects: [], origin: nil)
        super(origin: origin)
        @name = name
        @params = params  # Array of Param
        @ret_type = ret_type
        @body = body
        @effects = effects  # Array of :noexcept, :constexpr, etc.
      end
    end
    
    # Function parameter
    class Param < Node
      attr_reader :name, :type
      
      def initialize(name:, type:, origin: nil)
        super(origin: origin)
        @name = name
        @type = type
      end
    end
    
    # Expressions (normalized, no sugar)
    class Expr < Node
      attr_reader :kind, :data, :type
      
      def initialize(kind:, data:, type: nil, origin: nil)
        super(origin: origin)
        @kind = kind  # :lit/:var/:call/:binary/:let
        @data = data
        @type = type
      end
    end
    
    # Literal expression
    class LiteralExpr < Expr
      attr_reader :value
      
      def initialize(value:, type:, origin: nil)
        super(kind: :lit, data: value, type: type, origin: origin)
        @value = value
      end
    end
    
    # Variable reference
    class VarExpr < Expr
      attr_reader :name
      
      def initialize(name:, type:, origin: nil)
        super(kind: :var, data: name, type: type, origin: origin)
        @name = name
      end
    end
    
    # Binary operation
    class BinaryExpr < Expr
      attr_reader :op, :left, :right
      
      def initialize(op:, left:, right:, type:, origin: nil)
        super(kind: :binary, data: {op: op, left: left, right: right}, type: type, origin: origin)
        @op = op
        @left = left
        @right = right
      end
    end
    
    # Function call
    class CallExpr < Expr
      attr_reader :callee, :args
      
      def initialize(callee:, args:, type:, origin: nil)
        super(kind: :call, data: {callee: callee, args: args}, type: type, origin: origin)
        @callee = callee
        @args = args
      end
    end
    
    # Member access
    class MemberExpr < Expr
      attr_reader :object, :member
      
      def initialize(object:, member:, type:, origin: nil)
        super(kind: :member, data: {object: object, member: member}, type: type, origin: origin)
        @object = object
        @member = member
      end
    end
    
    # Let binding
    class LetExpr < Expr
      attr_reader :name, :value, :body
      
      def initialize(name:, value:, body:, type:, origin: nil)
        super(kind: :let, data: {name: name, value: value, body: body}, type: type, origin: origin)
        @name = name
        @value = value
        @body = body
      end
    end
    
    # Record literal
    class RecordExpr < Expr
      attr_reader :type_name, :fields
      
      def initialize(type_name:, fields:, type:, origin: nil)
        super(kind: :record, data: {type_name: type_name, fields: fields}, type: type, origin: origin)
        @type_name = type_name
        @fields = fields  # Hash of {field_name => value}
      end
    end
    
    # Statements
    class Stmt < Node
    end
    
    # Block of statements
    class Block < Stmt
      attr_reader :stmts
      
      def initialize(stmts:, origin: nil)
        super(origin: origin)
        @stmts = stmts
      end
    end
    
    # Return statement
    class Return < Stmt
      attr_reader :expr
      
      def initialize(expr:, origin: nil)
        super(origin: origin)
        @expr = expr
      end
    end
    
    # Type declaration
    class TypeDecl < Node
      attr_reader :name, :type
      
      def initialize(name:, type:, origin: nil)
        super(origin: origin)
        @name = name
        @type = type
      end
    end
  end
end
