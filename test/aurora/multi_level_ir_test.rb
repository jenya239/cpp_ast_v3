# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/aurora/analysis/base_pass"
require_relative "../../lib/aurora/analysis/identity_lowering_pass"
require_relative "../../lib/aurora/analysis/name_resolution_pass"

class MultiLevelIRTest < Minitest::Test
  def setup
    @source = <<~AURORA
      fn add(x: i32, y: i32) -> i32 = x + y
      fn main() -> i32 = add(2, 3)
    AURORA

    ast = Aurora.parse(@source)
    @core_ir, @type_registry = Aurora.transform_to_core_with_registry(ast)
  end

  def test_pass_metadata
    pass = Aurora::Analysis::IdentityLoweringPass.new

    assert_equal :high_ir, pass.input_level
    assert_equal :mid_ir, pass.output_level
    assert_equal [:core_ir], pass.required_keys
    assert_equal [:mid_ir], pass.produced_keys
    assert pass.transformation?, "Should be a transformation pass"
  end

  def test_identity_lowering_pass
    pass = Aurora::Analysis::IdentityLoweringPass.new
    context = { core_ir: @core_ir }

    pass.run(context)

    assert context[:mid_ir], "Mid IR should be produced"
    assert_equal :mid_ir, context[:current_ir_level]

    # For now, Mid IR is the same as High IR (identity transformation)
    assert_equal @core_ir, context[:mid_ir]
  end

  def test_pass_validation
    pass = Aurora::Analysis::IdentityLoweringPass.new
    context = {}  # Empty context - missing required keys

    error = assert_raises(ArgumentError) do
      pass.validate_context!(context)
    end

    assert_includes error.message, "missing required context keys"
    assert_includes error.message, "core_ir"
  end

  def test_multi_level_pipeline
    # Create a pipeline: High IR → analysis → lowering → Mid IR
    manager = Aurora::PassManager.new

    # Analysis passes on High IR
    manager.register(:name_resolution, Aurora::Analysis::NameResolutionPass.new.to_callable)

    # Lowering pass: High IR → Mid IR
    manager.register(:lower_to_mid, Aurora::Analysis::IdentityLoweringPass.new.to_callable)

    context = { core_ir: @core_ir }
    manager.run(context)

    # Verify pipeline results
    assert context[:symbol_table], "Name resolution should have run"
    assert context[:mid_ir], "Lowering should have produced Mid IR"
    assert_equal :mid_ir, context[:current_ir_level]
  end

  def test_pass_metadata_for_analysis_passes
    # Analysis passes don't change IR level
    name_pass = Aurora::Analysis::NameResolutionPass.new

    assert_equal :high_ir, name_pass.input_level
    assert_equal :high_ir, name_pass.output_level
    refute name_pass.transformation?, "Analysis pass should not be transformation"
  end
end
