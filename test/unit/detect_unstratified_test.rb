require 'fileutils'
require 'digest'
require_relative '../test_helper'

class DetectUnstratifiedTest < Test::Unit::TestCase
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')

  def test_parsed_populations
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_missing_unstratified.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))\

    simple_xml_model.populations.length.must_equal 3
    simple_xml_model.populations[0].keys.include?('STRAT').must_equal false
    simple_xml_model.populations[1].keys.include?('STRAT').must_equal true
    simple_xml_model.populations[2].keys.include?('STRAT').must_equal true
  end

end
