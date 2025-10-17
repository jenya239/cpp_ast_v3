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

    # Sum type (variant/tagged union)
    class SumType < Type
      attr_reader :variants

      def initialize(name:, variants:, origin: nil)
        super(kind: :sum, name: name, origin: origin)
        @variants = variants  # Array of {name: String, fields: Array of {name:, type:}}
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
      attr_reader :name, :items, :imports

      def initialize(name:, items:, imports: [], origin: nil)
        super(origin: origin)
        @name = name          # String or nil (for main/anonymous modules)
        @imports = imports    # Array of Import
        @items = items        # Array of declarations
      end
    end

    # Import declaration
    class Import < Node
      attr_reader :path, :items

      def initialize(path:, items: nil, origin: nil)
        super(origin: origin)
        @path = path    # String (e.g., "Math::Vector")
        @items = items  # nil (import all) or Array of String (selective import)
      end
    end

    # Alias for compatibility
    Program = Module
    
    # Function declaration
    class Func < Node
      attr_reader :name, :params, :ret_type, :body, :effects, :type_params

      def initialize(name:, params:, ret_type:, body:, effects: [], type_params: [], origin: nil)
        super(origin: origin)
        @name = name
        @params = params  # Array of Param
        @ret_type = ret_type
        @body = body
        @effects = effects  # Array of :noexcept, :constexpr, etc.
        @type_params = type_params  # Array of String (type parameter names)
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

    # Index access (array indexing)
    class IndexExpr < Expr
      attr_reader :object, :index

      def initialize(object:, index:, type:, origin: nil)
        super(kind: :index, data: {object: object, index: index}, type: type, origin: origin)
        @object = object  # Expr - array being indexed
        @index = index    # Expr - index expression
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

    # If expression
    class IfExpr < Expr
      attr_reader :condition, :then_branch, :else_branch

      def initialize(condition:, then_branch:, else_branch:, type:, origin: nil)
        super(kind: :if, data: {condition: condition, then_branch: then_branch, else_branch: else_branch}, type: type, origin: origin)
        @condition = condition
        @then_branch = then_branch
        @else_branch = else_branch
      end
    end

    # Match expression
    class MatchExpr < Expr
      attr_reader :scrutinee, :arms

      def initialize(scrutinee:, arms:, type:, origin: nil)
        super(kind: :match, data: {scrutinee: scrutinee, arms: arms}, type: type, origin: origin)
        @scrutinee = scrutinee  # Expression being matched
        @arms = arms  # Array of {pattern:, guard:, body:}
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
      attr_reader :name, :type, :type_params

      def initialize(name:, type:, type_params: [], origin: nil)
        super(origin: origin)
        @name = name
        @type = type
        @type_params = type_params  # Array of String (type parameter names)
      end
    end

    # Lambda expression (anonymous function)
    class LambdaExpr < Expr
      attr_reader :captures, :params, :body, :function_type

      def initialize(captures:, params:, body:, function_type:, origin: nil)
        super(kind: :lambda, data: {params: params, body: body}, type: function_type, origin: origin)
        @captures = captures      # Array of {name: String, type: Type, mode: :value/:ref}
        @params = params          # Array of Param (fully typed)
        @body = body              # Expr
        @function_type = function_type  # FunctionType
      end
    end

    # For loop (imperative)
    class ForLoopExpr < Expr
      attr_reader :var_name, :var_type, :iterable, :body

      def initialize(var_name:, var_type:, iterable:, body:, origin: nil)
        super(kind: :for_loop, data: {}, type: Type.new(kind: :prim, name: "void"), origin: origin)
        @var_name = var_name
        @var_type = var_type   # Inferred element type
        @iterable = iterable
        @body = body
      end
    end

    # List comprehension desugars to loop + push
    class ListCompExpr < Expr
      attr_reader :element_type, :generators, :filters, :output_expr

      def initialize(element_type:, generators:, filters:, output_expr:, type:, origin: nil)
        super(kind: :list_comp, data: {}, type: type, origin: origin)
        @element_type = element_type
        @generators = generators
        @filters = filters
        @output_expr = output_expr
      end
    end

    # Array literal
    class ArrayLiteralExpr < Expr
      attr_reader :elements

      def initialize(elements:, type:, origin: nil)
        super(kind: :array_lit, data: elements, type: type, origin: origin)
        @elements = elements  # Array of Expr
      end
    end

    # Array type
    class ArrayType < Type
      attr_reader :element_type

      def initialize(element_type:, origin: nil)
        super(kind: :array, name: "array", origin: origin)
        @element_type = element_type
      end
    end
  end
end
