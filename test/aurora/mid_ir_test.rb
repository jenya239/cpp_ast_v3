# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora/mid_ir/nodes"
require_relative "../../lib/aurora/analysis/lower_to_mid_pass"

class MidIRTest < Minitest::Test
  def setup
    # Empty setup
  end

  def test_simple_arithmetic_lowering
    source = <<~AURORA
      fn add(x: i32, y: i32) -> i32 = x + y
      fn main() -> i32 = add(2, 3)
    AURORA

    ast = Aurora.parse(source)
    high_ir, _registry = Aurora.transform_to_core_with_registry(ast)

    # Lower to Mid IR
    pass = Aurora::Analysis::LowerToMidPass.new
    context = { core_ir: high_ir }
    pass.run(context)

    mid_ir = context[:mid_ir]

    assert mid_ir, "Mid IR should be created"
    assert_instance_of Aurora::MidIR::Module, mid_ir
    assert_equal "main", mid_ir.name

    # Check functions
    functions = mid_ir.items.select { |item| item.is_a?(Aurora::MidIR::Function) }
    assert_equal 2, functions.size, "Should have 2 functions"

    # Check add function
    add_func = functions.find { |f| f.name == "add" }
    assert add_func, "Should have 'add' function"
    assert_equal 2, add_func.params.size
    assert_equal 1, add_func.blocks.size, "Simple function should have 1 block"
  end

  def test_if_expression_creates_basic_blocks
    source = <<~AURORA
      fn abs(x: i32) -> i32 =
        if x < 0 then -x else x
    AURORA

    ast = Aurora.parse(source)
    high_ir, _registry = Aurora.transform_to_core_with_registry(ast)

    # Lower to Mid IR
    pass = Aurora::Analysis::LowerToMidPass.new
    context = { core_ir: high_ir }
    pass.run(context)

    mid_ir = context[:mid_ir]
    abs_func = mid_ir.items.find { |item| item.is_a?(Aurora::MidIR::Function) && item.name == "abs" }

    assert abs_func, "Should have 'abs' function"

    # If expression should create multiple basic blocks:
    # entry, then, else, merge
    assert abs_func.blocks.size >= 4, "If expression should create at least 4 basic blocks (entry, then, else, merge)"

    # Check entry block has branch terminator
    entry_block = abs_func.blocks.first
    assert_instance_of Aurora::MidIR::Branch, entry_block.terminator,
      "Entry block should have branch terminator"

    # Check then/else blocks have jump terminators
    then_block = abs_func.blocks[1]
    assert_instance_of Aurora::MidIR::Jump, then_block.terminator,
      "Then block should have jump terminator"

    else_block = abs_func.blocks[2]
    assert_instance_of Aurora::MidIR::Jump, else_block.terminator,
      "Else block should have jump terminator"
  end

  def test_basic_block_structure
    source = <<~AURORA
      fn test(x: i32) -> i32 =
        if x > 0 then x * 2 else 0
    AURORA

    ast = Aurora.parse(source)
    high_ir, _registry = Aurora.transform_to_core_with_registry(ast)

    pass = Aurora::Analysis::LowerToMidPass.new
    context = { core_ir: high_ir }
    pass.run(context)

    mid_ir = context[:mid_ir]
    test_func = mid_ir.items.find { |item| item.is_a?(Aurora::MidIR::Function) && item.name == "test" }

    # Each basic block should have:
    # - label (String)
    # - instructions (Array)
    # - terminator (Jump/Branch/Return)
    test_func.blocks.each do |block|
      assert_instance_of String, block.label, "Block should have string label"
      assert_instance_of Array, block.instructions, "Block should have instructions array"
      assert block.terminator, "Block should have terminator"
      assert [Aurora::MidIR::Jump, Aurora::MidIR::Branch, Aurora::MidIR::Return].any? { |klass| block.terminator.is_a?(klass) },
        "Terminator should be Jump, Branch, or Return"
    end
  end

  def test_function_call_lowering
    source = <<~AURORA
      fn double(x: i32) -> i32 = x * 2
      fn main() -> i32 = double(5)
    AURORA

    ast = Aurora.parse(source)
    high_ir, _registry = Aurora.transform_to_core_with_registry(ast)

    pass = Aurora::Analysis::LowerToMidPass.new
    context = { core_ir: high_ir }
    pass.run(context)

    mid_ir = context[:mid_ir]
    main_func = mid_ir.items.find { |item| item.is_a?(Aurora::MidIR::Function) && item.name == "main" }

    assert main_func, "Should have 'main' function"

    # Check that return contains a call
    entry_block = main_func.blocks.first
    return_terminator = entry_block.terminator

    assert_instance_of Aurora::MidIR::Return, return_terminator
    assert_instance_of Aurora::MidIR::Call, return_terminator.value
    assert_equal "double", return_terminator.value.callee
  end

  def test_temporary_variables_creation
    source = <<~AURORA
      fn test(x: i32) -> i32 =
        if x > 0 then x + 1 else x - 1
    AURORA

    ast = Aurora.parse(source)
    high_ir, _registry = Aurora.transform_to_core_with_registry(ast)

    pass = Aurora::Analysis::LowerToMidPass.new
    context = { core_ir: high_ir }
    pass.run(context)

    mid_ir = context[:mid_ir]
    test_func = mid_ir.items.find { |item| item.is_a?(Aurora::MidIR::Function) && item.name == "test" }

    # Check that temporary variables are created in blocks
    has_temps = test_func.blocks.any? do |block|
      block.instructions.any? do |inst|
        inst.is_a?(Aurora::MidIR::Assign) && inst.dest.start_with?("t")
      end
    end

    assert has_temps, "Should create temporary variables (t0, t1, etc.)"
  end
end
