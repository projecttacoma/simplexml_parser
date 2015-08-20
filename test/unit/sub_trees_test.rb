require 'fileutils'
require 'digest'
require_relative '../test_helper'

class SubTreesTest < Minitest::Test
  RESULTS_DIR = File.join('tmp','with_sub_trees')
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')

  # Create a blank folder for results
  FileUtils.rm_rf(RESULTS_DIR) if File.directory?(RESULTS_DIR)
  FileUtils.mkdir_p RESULTS_DIR

  def test_with_sub_trees
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_sub_trees.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    # outfile = File.join("#{RESULTS_DIR}","result.json")
    # File.open(outfile, 'w') {|f| f.write(JSON.pretty_generate(simple_xml_model.to_json)) }

    assert_equal 13, simple_xml_model.all_data_criteria.count
    assert_equal 3, simple_xml_model.population_criteria('IPP').preconditions.first.preconditions.count
    assert_equal ['a real comment'], simple_xml_model.population_criteria('IPP').preconditions.first.comments

  end

  def test_with_satisfies_all
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_satisfies_all.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    assert_equal 8, simple_xml_model.all_data_criteria.count
    assert_equal 'INTERSECT', simple_xml_model.data_criteria('GROUP_satisfiesAll_CHILDREN_5').derivation_operator.to_s
    assert_equal "derived", simple_xml_model.data_criteria('GROUP_satisfiesAll_CHILDREN_5').type.to_s
    assert_equal 'satisfies_all', simple_xml_model.data_criteria('GROUP_satisfiesAll_CHILDREN_5').definition.to_s
  end

  def test_with_satisfies_any
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_satisfies_any.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    assert_equal 8, simple_xml_model.all_data_criteria.count
    assert_equal 'UNION', simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_5').derivation_operator.to_s
    assert_equal "derived", simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_5').type.to_s
    assert_equal 'satisfies_any', simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_5').definition.to_s
  end

  def test_with_variable
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_variable.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    assert_equal 9, simple_xml_model.all_data_criteria.count
    assert_equal 'UNION', simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').derivation_operator.to_s
    assert_equal "derived", simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').type.to_s
    assert_equal 'derived', simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').definition.to_s
    assert_equal true, simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').variable

    assert_equal 'UNION', simple_xml_model.source_data_criteria[6].derivation_operator.to_s
    assert_equal "derived", simple_xml_model.source_data_criteria[6].type.to_s
    assert_equal 'derived', simple_xml_model.source_data_criteria[6].definition.to_s
    assert_equal true, simple_xml_model.source_data_criteria[6].variable
  end

  def test_with_specific_variable
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_specific_variable.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    assert_equal 9, simple_xml_model.all_data_criteria.count
    assert_equal 'UNION', simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').derivation_operator.to_s
    assert_equal "derived", simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').type.to_s
    assert_equal 'derived', simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').definition.to_s
    assert_equal true, simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').variable
    assert_equal 'A', simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').specific_occurrence.to_s
    assert_equal 'VARIABLE', simple_xml_model.data_criteria('GROUP_variable_CHILDREN_7').specific_occurrence_const.to_s

    assert_equal 'UNION', simple_xml_model.source_data_criteria[6].derivation_operator.to_s
    assert_equal "derived", simple_xml_model.source_data_criteria[6].type.to_s
    assert_equal 'derived', simple_xml_model.source_data_criteria[6].definition.to_s
    assert_equal true, simple_xml_model.source_data_criteria[6].variable
    assert_equal 'A', simple_xml_model.source_data_criteria[6].specific_occurrence
    assert_equal 'VARIABLE', simple_xml_model.source_data_criteria[6].specific_occurrence_const
  end

  def test_with_during_intersection
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_during_intersection.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    ipp = simple_xml_model.population_criteria('IPP')
    assert_equal 1, ipp.preconditions.count
    assert_equal "allTrue", ipp.preconditions.first.conjunction_code
    assert_equal 1, ipp.preconditions.first.preconditions.count
    assert_equal "GROUP_INTERSECT_CHILDREN_19", ipp.preconditions.first.preconditions.first.reference.id

    assert_equal 12, simple_xml_model.all_data_criteria.count

    intersection = simple_xml_model.data_criteria('GROUP_INTERSECT_CHILDREN_19')
    assert_equal 'INTERSECT', intersection.derivation_operator.to_s
    assert_equal 2, intersection.children_criteria.size
    assert_equal 1, intersection.temporal_references.size
    assert_equal 'DURING', intersection.temporal_references.first.type
    assert_equal 'GROUP_UNION_CHILDREN_10', intersection.temporal_references.first.reference.id
  end

  def test_with_age_at_with_birthdate
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_age_at_with_birthdate.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    assert_equal 9, simple_xml_model.all_data_criteria.count
    assert_equal 'patient_characteristic_birthdate', simple_xml_model.data_criteria('PatientCharacteristicBirthdateBirthdate_precondition_3').definition.to_s
    assert_equal 'SBS', simple_xml_model.data_criteria('PatientCharacteristicBirthdateBirthdate_precondition_3').temporal_references[0].type.to_s
  end

  def test_with_age_at_without_birthdate
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_age_at_without_birthdate.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    assert_equal 8, simple_xml_model.all_data_criteria.count
    assert_equal 'patient_characteristic_birthdate', simple_xml_model.data_criteria('PatientCharacteristicBirthdateBirthdate_precondition_3').definition.to_s
    assert_equal 'SBS', simple_xml_model.data_criteria('PatientCharacteristicBirthdateBirthdate_precondition_3').temporal_references[0].type.to_s
  end

end
