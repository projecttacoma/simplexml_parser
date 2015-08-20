require 'fileutils'
require 'digest'
require_relative '../test_helper'

class FulfillsTest < Minitest::Test
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')


  def test_with_sub_trees
    simple_xml = File.join(SIMPLE_XML_ROOT, "fulfills.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))
    dc = simple_xml_model.data_criteria("DiagnosisActiveIschemicStroke_precondition_22")
    assert dc
    assert_equal "MedicationOrderAntithromboticTherapy", dc.field_values["FLFS"].reference
   
  end
end
