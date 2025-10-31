# frozen_string_literal: true

module MLC
  module MidIR
    # Mid IR - simplified intermediate representation
    # Key differences from High IR (HighIR):
    # - No high-level constructs (match, comprehensions)
    # - Explicit control flow (basic blocks, jumps)
    # - If/While are statements, not expressions
    # - Temporary variables explicit
    #
    # But still maintains:
    # - Type information
    # - Structured (not SSA yet)
    # - Human-readable

    # Base node class
    class Node
      attr_reader :origin, :type

      def initialize(origin: nil, type: nil)
        @origin = origin
        @type = type
      end
    end

    # Module - top-level container
    class Module < Node
      attr_reader :name, :items

      def initialize(name:, items:, origin: nil)
        super(origin: origin)
        @name = name
        @items = items  # Array of Function, TypeDecl
      end
    end

    # Function with basic blocks
    class Function < Node
      attr_reader :name, :params, :ret_type, :blocks, :effects

      def initialize(name:, params:, ret_type:, blocks:, effects: [], origin: nil)
        super(origin: origin, type: ret_type)
        @name = name
        @params = params  # Array of Param
        @ret_type = ret_type
        @blocks = blocks  # Array of BasicBlock
        @effects = effects
      end
    end

    # Basic Block - sequence of instructions with single entry/exit
    class BasicBlock < Node
      attr_reader :label, :instructions
      attr_accessor :terminator  # Mutable so we can set it after creation

      def initialize(label:, instructions:, terminator: nil, origin: nil)
        super(origin: origin)
        @label = label  # String (e.g., "bb0", "bb_loop_entry")
        @instructions = instructions  # Array of Instruction
        @terminator = terminator  # Jump, Branch, Return
      end
    end

    # Parameter
    class Param < Node
      attr_reader :name

      def initialize(name:, type:, origin: nil)
        super(origin: origin, type: type)
        @name = name
      end
    end

    # Instructions (non-control-flow)
    class Instruction < Node
      attr_reader :dest, :value

      def initialize(dest:, value:, type: nil, origin: nil)
        super(origin: origin, type: type)
        @dest = dest  # String - destination variable name
        @value = value  # Expression
      end
    end

    # Assignment: x = value
    class Assign < Instruction
      def initialize(dest:, value:, type: nil, origin: nil)
        super(dest: dest, value: value, type: type, origin: origin)
      end
    end

    # Store: memory[addr] = value
    class Store < Instruction
      attr_reader :address

      def initialize(address:, value:, type: nil, origin: nil)
        super(dest: nil, value: value, type: type, origin: origin)
        @address = address
      end
    end

    # Simple expressions
    class Expr < Node
    end

    # Variable reference
    class Var < Expr
      attr_reader :name

      def initialize(name:, type: nil, origin: nil)
        super(origin: origin, type: type)
        @name = name
      end
    end

    # Literal value
    class Literal < Expr
      attr_reader :value

      def initialize(value:, type:, origin: nil)
        super(origin: origin, type: type)
        @value = value
      end
    end

    # Binary operation
    class BinaryOp < Expr
      attr_reader :op, :left, :right

      def initialize(op:, left:, right:, type: nil, origin: nil)
        super(origin: origin, type: type)
        @op = op  # String: "+", "-", "*", "/", "==", etc.
        @left = left
        @right = right
      end
    end

    # Unary operation
    class UnaryOp < Expr
      attr_reader :op, :operand

      def initialize(op:, operand:, type: nil, origin: nil)
        super(origin: origin, type: type)
        @op = op  # String: "-", "!", "~"
        @operand = operand
      end
    end

    # Function call
    class Call < Expr
      attr_reader :callee, :args

      def initialize(callee:, args:, type: nil, origin: nil)
        super(origin: origin, type: type)
        @callee = callee  # String - function name
        @args = args  # Array of Expr
      end
    end

    # Member access
    class Member < Expr
      attr_reader :object, :field

      def initialize(object:, field:, type: nil, origin: nil)
        super(origin: origin, type: type)
        @object = object  # Expr
        @field = field  # String
      end
    end

    # Load from memory
    class Load < Expr
      attr_reader :address

      def initialize(address:, type:, origin: nil)
        super(origin: origin, type: type)
        @address = address  # Expr
      end
    end

    # Terminators (control flow at end of basic block)
    class Terminator < Node
    end

    # Unconditional jump
    class Jump < Terminator
      attr_reader :target

      def initialize(target:, origin: nil)
        super(origin: origin)
        @target = target  # String - label of target BasicBlock
      end
    end

    # Conditional branch
    class Branch < Terminator
      attr_reader :condition, :true_target, :false_target

      def initialize(condition:, true_target:, false_target:, origin: nil)
        super(origin: origin)
        @condition = condition  # Expr
        @true_target = true_target  # String - label
        @false_target = false_target  # String - label
      end
    end

    # Return from function
    class Return < Terminator
      attr_reader :value

      def initialize(value: nil, origin: nil)
        super(origin: origin)
        @value = value  # Expr or nil for void
      end
    end

    # Type declarations (same as HighIR for now)
    class TypeDecl < Node
      attr_reader :name, :definition

      def initialize(name:, definition:, origin: nil)
        super(origin: origin)
        @name = name
        @definition = definition
      end
    end
  end
end
