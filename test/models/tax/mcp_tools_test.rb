# frozen_string_literal: true

require "test_helper"

class Tax::McpToolsTest < ActiveSupport::TestCase
  test "tax tools are registered for MCP via assistant function list" do
    user = users(:family_admin)
    assert Tax::McpTools.registered?(Assistant.function_classes(user))
  end
end
