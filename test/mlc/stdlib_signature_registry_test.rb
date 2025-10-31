# frozen_string_literal: true

require_relative "../test_helper"

class StdlibSignatureRegistryTest < Minitest::Test
  def setup
    @registry = MLC::StdlibSignatureRegistry.new
  end

  def test_fetches_function_metadata_with_ast_node
    info = @registry.module_info("IO")
    refute_nil info

    metadata = info.functions["println"]
    refute_nil metadata
    assert_equal "mlc::io::println", metadata.qualified_name
    assert_instance_of MLC::AST::FuncDecl, metadata.ast_node
  end

  def test_fetches_type_metadata_with_ast_node
    info = @registry.module_info("Option")
    refute_nil info

    metadata = info.types["Option"]
    refute_nil metadata
    assert_equal "mlc::option::Option", metadata.qualified_name
    assert_instance_of MLC::AST::TypeDecl, metadata.ast_node
  end
end
