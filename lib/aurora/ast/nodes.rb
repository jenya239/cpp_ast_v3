# frozen_string_literal: true

module Aurora
  module AST
    # Base node with origin tracking
    class Node
      attr_reader :origin
      
      def initialize(origin: nil)
        @origin = origin
      end
    end
    
    # Program root
    class Program < Node
      attr_reader :declarations
      
      def initialize(declarations:, origin: nil)
        super(origin: origin)
        @declarations = declarations
      end
    end
    
    # Type declarations
    class TypeDecl < Node
      attr_reader :name, :type
      
      def initialize(name:, type:, origin: nil)
        super(origin: origin)
        @name = name
        @type = type
      end
    end
    
    # Function declarations
    class FuncDecl < Node
      attr_reader :name, :params, :ret_type, :body
      
      def initialize(name:, params:, ret_type:, body:, origin: nil)
        super(origin: origin)
        @name = name
        @params = params
        @ret_type = ret_type
        @body = body
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
    
    # Types
    class Type < Node
      attr_reader :kind, :name, :fields
      
      def initialize(kind:, name:, fields: nil, origin: nil)
        super(origin: origin)
        @kind = kind  # :prim/:record
        @name = name
        @fields = fields  # For record types: Array of {name: String, type: Type}
      end
    end
    
    # Primitive type
    class PrimType < Type
      def initialize(name:, origin: nil)
        super(kind: :prim, name: name, origin: origin)
      end
    end
    
    # Record type
    class RecordType < Type
      def initialize(name:, fields:, origin: nil)
        super(kind: :record, name: name, fields: fields, origin: origin)
      end
    end
    
    # Expressions (with sugar)
    class Expr < Node
      attr_reader :kind, :data
      
      def initialize(kind:, data:, origin: nil)
        super(origin: origin)
        @kind = kind
        @data = data
      end
    end
    
    # Literal expressions
    class IntLit < Expr
      attr_reader :value
      
      def initialize(value:, origin: nil)
        super(kind: :int_lit, data: value, origin: origin)
        @value = value
      end
    end
    
    class FloatLit < Expr
      attr_reader :value
      
      def initialize(value:, origin: nil)
        super(kind: :float_lit, data: value, origin: origin)
        @value = value
      end
    end
    
    # Variable reference
    class VarRef < Expr
      attr_reader :name
      
      def initialize(name:, origin: nil)
        super(kind: :var_ref, data: name, origin: origin)
        @name = name
      end
    end
    
    # Binary operation
    class BinaryOp < Expr
      attr_reader :op, :left, :right
      
      def initialize(op:, left:, right:, origin: nil)
        super(kind: :binary, data: {op: op, left: left, right: right}, origin: origin)
        @op = op
        @left = left
        @right = right
      end
    end
    
    # Function call
    class Call < Expr
      attr_reader :callee, :args
      
      def initialize(callee:, args:, origin: nil)
        super(kind: :call, data: {callee: callee, args: args}, origin: origin)
        @callee = callee
        @args = args
      end
    end
    
    # Member access
    class MemberAccess < Expr
      attr_reader :object, :member
      
      def initialize(object:, member:, origin: nil)
        super(kind: :member, data: {object: object, member: member}, origin: origin)
        @object = object
        @member = member
      end
    end
    
    # Let binding (sugar)
    class Let < Expr
      attr_reader :name, :value, :body
      
      def initialize(name:, value:, body:, origin: nil)
        super(kind: :let, data: {name: name, value: value, body: body}, origin: origin)
        @name = name
        @value = value
        @body = body
      end
    end
    
    # Record literal
    class RecordLit < Expr
      attr_reader :type_name, :fields
      
      def initialize(type_name:, fields:, origin: nil)
        super(kind: :record_lit, data: {type_name: type_name, fields: fields}, origin: origin)
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
    
    # Expression statement
    class ExprStmt < Stmt
      attr_reader :expr
      
      def initialize(expr:, origin: nil)
        super(origin: origin)
        @expr = expr
      end
    end
  end
end
