require 'fileutils'
require 'digest'
require_relative '../test_helper'

class DetectUnstratifiedTest < Minitest::Test
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')

  def test_parsed_populations
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_missing_unstratified.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))\

    assert_equal 3, simple_xml_model.populations.length
    assert_equal false, simple_xml_model.populations[0].keys.include?('STRAT')
    assert_equal true, simple_xml_model.populations[1].keys.include?('STRAT')
    assert_equal true, simple_xml_model.populations[2].keys.include?('STRAT')
  end

end
