# frozen_string_literal: true

module MLC
  SourceOrigin = Struct.new(
    :file,
    :line,
    :column,
    :end_line,
    :end_column,
    :line_text,
    keyword_init: true
  ) do
    def start_line
      line
    end

    def start_column
      column
    end

    def label
      return nil unless line
      parts = []
      parts << (file || "<input>")
      parts << line.to_s
      parts << column.to_s if column
      parts.join(":")
    end

    def highlight
      return nil unless line_text && start_column
      indicator = highlight_indicator
      return line_text if indicator.nil?
      "#{line_text}\n#{indicator}"
    end

    private

    def highlight_indicator
      start_col = [start_column, 1].max
      finish_col = if end_column && end_column >= start_column.to_i
                     end_column
                   else
                     start_column
                   end
      width = finish_col - start_col + 1
      width = 1 if width <= 0
      " " * (start_col - 1) + "^" * width
    end
  end

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
      attr_reader :module_decl, :imports, :declarations

      def initialize(declarations:, module_decl: nil, imports: [], origin: nil)
        super(origin: origin)
        @module_decl = module_decl  # ModuleDecl or nil
        @imports = imports           # Array of ImportDecl
        @declarations = declarations
      end
    end

    # Module declaration
    class ModuleDecl < Node
      attr_reader :name

      def initialize(name:, origin: nil)
        super(origin: origin)
        @name = name  # String (e.g., "Math::Vector")
      end
    end

    # Import declaration
    class ImportDecl < Node
      attr_reader :path, :items, :import_all, :alias

      def initialize(path:, items: nil, import_all: false, alias_name: nil, origin: nil)
        super(origin: origin)
        @path = path           # String (e.g., "Math", "Math::Vector")
        @items = items         # Array of String (selective import) or nil
        @import_all = import_all  # Boolean - import * as ...
        @alias = alias_name    # String or nil - alias for import * as X
      end
    end
    
    # Type declarations
    class TypeDecl < Node
      attr_reader :name, :type, :type_params, :exported

      def initialize(name:, type:, type_params: [], exported: false, origin: nil)
        super(origin: origin)
        @name = name
        @type = type
        @type_params = type_params  # Array of TypeParam
        @exported = exported        # Boolean - is this exported?
      end
    end

    # Function declarations
    class FuncDecl < Node
      attr_reader :name, :params, :ret_type, :body, :type_params, :exported, :external

      def initialize(name:, params:, ret_type:, body: nil, type_params: [], exported: false, external: false, origin: nil)
        super(origin: origin)
        @name = name
        @params = params
        @ret_type = ret_type
        @body = body
        @type_params = type_params  # Array of TypeParam
        @exported = exported        # Boolean - is this exported?
        @external = external        # Boolean - is this an external (C++) function?
      end
    end

    # Type parameter with optional constraint
    class TypeParam < Node
      attr_reader :name, :constraint

      def initialize(name:, constraint: nil, origin: nil)
        super(origin: origin)
        @name = name
        @constraint = constraint
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

    # Enum type
    class EnumType < Type
      attr_reader :variants

      def initialize(name:, variants:, origin: nil)
        super(kind: :enum, name: name, origin: origin)
        @variants = variants  # Array of String
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

    # Array type
    class ArrayType < Type
      attr_reader :element_type

      def initialize(element_type:, origin: nil)
        super(kind: :array, name: "array", origin: origin)
        @element_type = element_type
      end
    end

    # Opaque type - type without known structure in Aurora
    # Represented as pointer in C++, can only come from extern/stdlib
    class OpaqueType < Type
      def initialize(name:, origin: nil)
        super(kind: :opaque, name: name, origin: origin)
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

    # Unit literal - represents void/unit type ()
    class UnitLit < Expr
      def initialize(origin: nil)
        super(kind: :unit_lit, data: nil, origin: origin)
      end
    end

    class FloatLit < Expr
      attr_reader :value

      def initialize(value:, origin: nil)
        super(kind: :float_lit, data: value, origin: origin)
        @value = value
      end
    end

    # String literal
    class StringLit < Expr
      attr_reader :value

      def initialize(value:, origin: nil)
        super(kind: :string_lit, data: value, origin: origin)
        @value = value
      end
    end

    # Regex literal
    class RegexLit < Expr
      attr_reader :pattern, :flags

      def initialize(pattern:, flags: "", origin: nil)
        super(kind: :regex_lit, data: {pattern: pattern, flags: flags}, origin: origin)
        @pattern = pattern  # String - regex pattern
        @flags = flags      # String - flags like "i", "m", "im"
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

    # Unary operation
    class UnaryOp < Expr
      attr_reader :op, :operand

      def initialize(op:, operand:, origin: nil)
        super(kind: :unary, data: {op: op, operand: operand}, origin: origin)
        @op = op
        @operand = operand
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

    # Index access (array indexing): arr[index]
    class IndexAccess < Expr
      attr_reader :object, :index

      def initialize(object:, index:, origin: nil)
        super(kind: :index, data: {object: object, index: index}, origin: origin)
        @object = object  # Expr - the array/object being indexed
        @index = index    # Expr - the index expression
      end
    end
    
    # Let binding (sugar)
    class Let < Expr
      attr_reader :name, :value, :body, :mutable, :type

      def initialize(name:, value:, body:, mutable: false, type: nil, origin: nil)
        super(kind: :let, data: {name: name, value: value, body: body}, origin: origin)
        @name = name
        @value = value
        @body = body
        @mutable = mutable
        @type = type  # Optional type annotation
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
    
    # If expression
    class IfExpr < Expr
      attr_reader :condition, :then_branch, :else_branch

      def initialize(condition:, then_branch:, else_branch:, origin: nil)
        super(kind: :if, data: {condition: condition, then_branch: then_branch, else_branch: else_branch}, origin: origin)
        @condition = condition
        @then_branch = then_branch
        @else_branch = else_branch
      end
    end

    # Do expression - block of statements returning the last expression
    class DoExpr < Expr
      attr_reader :body

      def initialize(body:, origin: nil)
        super(kind: :do, data: {body: body}, origin: origin)
        @body = body  # Array of expressions
      end
    end

    # Block expression - unified block construct with statements and result expression
    # This unifies do-blocks, while bodies, for bodies, and function bodies
    class BlockExpr < Expr
      attr_reader :statements, :result_expr

      def initialize(statements:, result_expr:, origin: nil)
        super(kind: :block_expr, data: {statements: statements, result_expr: result_expr}, origin: origin)
        @statements = statements    # Array of Stmt nodes (VariableDecl, Assignment, ExprStmt)
        @result_expr = result_expr  # Single Expr node - the result value of the block
      end
    end

    # Match expression
    class MatchExpr < Expr
      attr_reader :scrutinee, :arms

      def initialize(scrutinee:, arms:, origin: nil)
        super(kind: :match, data: {scrutinee: scrutinee, arms: arms}, origin: origin)
        @scrutinee = scrutinee  # Expression to match against
        @arms = arms  # Array of {pattern:, guard:, body:}
      end
    end

    # Pattern for match arms
    class Pattern < Node
      attr_reader :kind, :data

      def initialize(kind:, data:, origin: nil)
        super(origin: origin)
        @kind = kind  # :wildcard, :literal, :constructor, :var
        @data = data
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

      def initialize(expr: nil, origin: nil)
        super(origin: origin)
        @expr = expr
      end
    end

    # Break statement
    class Break < Stmt
      def initialize(origin: nil)
        super(origin: origin)
      end
    end

    # Continue statement
    class Continue < Stmt
      def initialize(origin: nil)
        super(origin: origin)
      end
    end

    # Variable declaration statement
    class VariableDecl < Stmt
      attr_reader :name, :value, :mutable, :type

      def initialize(name:, value:, mutable: false, type: nil, origin: nil)
        super(origin: origin)
        @name = name
        @value = value
        @mutable = mutable
        @type = type  # Optional type annotation
      end
    end

    # Assignment statement
    class Assignment < Stmt
      attr_reader :target, :value

      def initialize(target:, value:, origin: nil)
        super(origin: origin)
        @target = target
        @value = value
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

    # If statement
    class IfStmt < Stmt
      attr_reader :condition, :then_branch, :else_branch

      def initialize(condition:, then_branch:, else_branch: nil, origin: nil)
        super(origin: origin)
        @condition = condition
        @then_branch = then_branch
        @else_branch = else_branch
      end
    end

    # While statement
    class WhileStmt < Stmt
      attr_reader :condition, :body

      def initialize(condition:, body:, origin: nil)
        super(origin: origin)
        @condition = condition
        @body = body
      end
    end

    # Lambda expression
    class Lambda < Expr
      attr_reader :params, :body, :return_type

      def initialize(params:, body:, return_type: nil, origin: nil)
        super(kind: :lambda, data: {params: params, body: body}, origin: origin)
        @params = params      # Array of LambdaParam or String (inferred)
        @body = body          # Expr
        @return_type = return_type  # Optional Type
      end
    end

    # Lambda parameter (can be name-only or typed)
    class LambdaParam < Node
      attr_reader :name, :type

      def initialize(name:, type: nil, origin: nil)
        super(origin: origin)
        @name = name
        @type = type  # nil for inference
      end
    end

    # For loop expression
    class ForLoop < Expr
      attr_reader :var_name, :iterable, :body

      def initialize(var_name:, iterable:, body:, origin: nil)
        super(kind: :for_loop, data: {var: var_name, iter: iterable, body: body}, origin: origin)
        @var_name = var_name   # String
        @iterable = iterable   # Expr (array, range, etc.)
        @body = body           # Expr or Block
      end
    end

    # While loop expression
    class WhileLoop < Expr
      attr_reader :condition, :body

      def initialize(condition:, body:, origin: nil)
        super(kind: :while_loop, data: {condition: condition, body: body}, origin: origin)
        @condition = condition  # Expr
        @body = body            # Expr or Block
      end
    end

    # Range expression (for ranges like 0..10)
    class RangeExpr < Expr
      attr_reader :start, :end_expr, :inclusive

      def initialize(start:, end_expr:, inclusive: true, origin: nil)
        super(kind: :range, data: {start: start, end: end_expr}, origin: origin)
        @start = start         # Expr
        @end_expr = end_expr   # Expr (renamed to avoid conflict with Ruby's 'end')
        @inclusive = inclusive # true for .., false for ..<
      end
    end

    # List comprehension
    class ListComprehension < Expr
      attr_reader :output_expr, :generators, :filters

      def initialize(output_expr:, generators:, filters: [], origin: nil)
        super(kind: :list_comp, data: {}, origin: origin)
        @output_expr = output_expr  # Expr - what to collect
        @generators = generators    # Array of Generator
        @filters = filters          # Array of Expr (conditions)
      end
    end

    # Generator (part of comprehension)
    class Generator < Node
      attr_reader :var_name, :iterable

      def initialize(var_name:, iterable:, origin: nil)
        super(origin: origin)
        @var_name = var_name
        @iterable = iterable
      end
    end

    # Array literal
    class ArrayLiteral < Expr
      attr_reader :elements

      def initialize(elements:, origin: nil)
        super(kind: :array_lit, data: elements, origin: origin)
        @elements = elements  # Array of Expr
      end
    end

    # Pipe operation
    class PipeOp < Expr
      attr_reader :left, :right

      def initialize(left:, right:, origin: nil)
        super(kind: :pipe, data: {left: left, right: right}, origin: origin)
        @left = left    # Expr - value being piped
        @right = right  # Expr - usually Call, receives left as first arg
      end
    end

    # Function type
    class FunctionType < Type
      attr_reader :param_types, :ret_type

      def initialize(param_types:, ret_type:, origin: nil)
        super(kind: :func, name: "function", origin: origin)
        @param_types = param_types  # Array of Type
        @ret_type = ret_type
      end
    end

    # Tuple type (for multi-parameter function types)
    class TupleType < Type
      attr_reader :types

      def initialize(types:, origin: nil)
        super(kind: :tuple, name: "tuple", origin: origin)
        @types = types  # Array of Type
      end
    end

    # Generic type (e.g., Result<T, E>, Option<T>)
    class GenericType < Type
      attr_reader :base_type, :type_params

      def initialize(base_type:, type_params:, origin: nil)
        super(kind: :generic, name: base_type.name, origin: origin)
        @base_type = base_type    # Type (e.g., Result, Option)
        @type_params = type_params # Array of Type
      end
    end
  end
end
