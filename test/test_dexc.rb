require 'test/unit'

class TestDexc < Test::Unit::TestCase
  def test_load
    assert_nothing_raised do
      require_relative '../lib/dexc'
    end
  end
end
