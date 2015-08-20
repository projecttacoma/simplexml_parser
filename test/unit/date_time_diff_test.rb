require 'fileutils'
require 'digest'
require_relative '../test_helper'

class DateTimeDiffTest < Minitest::Test
  RESULTS_DIR = File.join('tmp','datetimediff')
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')

  # Create a blank folder for results
  FileUtils.rm_rf(RESULTS_DIR) if File.directory?(RESULTS_DIR)
  FileUtils.mkdir_p RESULTS_DIR

  def test_date_time_diff
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_datetimediff.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    assert_equal 21, simple_xml_model.all_data_criteria.count
    assert_equal 4, simple_xml_model.populations.count

    observ = simple_xml_model.population_criteria('OBSERV')
    assert_equal "MEDIAN", observ.aggregator
    dcId = observ.preconditions.first.reference.id
    dc = simple_xml_model.data_criteria(dcId)
    assert_equal 1, dc.subset_operators.count
    assert_equal "DATETIMEDIFF", dc.subset_operators[0].type

    observ = simple_xml_model.population_criteria('OBSERV_1')
    assert_equal "MEDIAN", observ.aggregator
    dcId = observ.preconditions.first.reference.id
    dc = simple_xml_model.data_criteria(dcId)
    assert_equal 1, dc.subset_operators.count
    assert_equal "DATETIMEDIFF", dc.subset_operators[0].type

    observ = simple_xml_model.population_criteria('OBSERV_2')
    assert_equal "MEDIAN", observ.aggregator
    dcId = observ.preconditions.first.reference.id
    dc = simple_xml_model.data_criteria(dcId)
    assert_equal 1, dc.subset_operators.count
    assert_equal "DATETIMEDIFF", dc.subset_operators[0].type

    observ = simple_xml_model.population_criteria('OBSERV_3')
    assert_equal "MEDIAN", observ.aggregator
    dcId = observ.preconditions.first.reference.id
    dc = simple_xml_model.data_criteria(dcId)
    assert_equal 1, dc.subset_operators.count
    assert_equal "DATETIMEDIFF", dc.subset_operators[0].type
    comparison = dc.subset_operators[0].value.low
    assert_equal "PQ", comparison.type
    assert_equal "d", comparison.unit
    assert_equal "3", comparison.value


  end


end
