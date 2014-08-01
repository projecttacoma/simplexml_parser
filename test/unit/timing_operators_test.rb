require 'fileutils'
require 'digest'
require_relative '../test_helper'

class MissingOidsTest < Test::Unit::TestCase
  RESULTS_DIR = File.join('tmp','with_timing_operators')
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')

  # Create a blank folder for results
  FileUtils.rm_rf(RESULTS_DIR) if File.directory?(RESULTS_DIR)
  FileUtils.mkdir_p RESULTS_DIR

  def test_with_missing_oids
    simple_xml = File.join(SIMPLE_XML_ROOT, "all_timing_operators.xml")
    simple_xml_model = SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml))

    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_136').derivation_operator.to_s.must_equal 'UNION'
    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_136').type.to_s.must_equal "derived"
    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_136').definition.to_s.must_equal 'satisfies_any'
    simple_xml_model.data_criteria('GROUP_satisfiesAny_CHILDREN_136').children_criteria.length.must_equal 25

    # verify MATv4.0.0 timing operators are correctly handled for HQMF2JS calculations
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_86').temporal_references[0].type.to_s.must_equal 'CONCURRENT'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_88').temporal_references[0].type.to_s.must_equal 'DURING'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_90').temporal_references[0].type.to_s.must_equal 'EAE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_92').temporal_references[0].type.to_s.must_equal 'EACW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_94').temporal_references[0].type.to_s.must_equal 'EACWS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_96').temporal_references[0].type.to_s.must_equal 'EAS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_98').temporal_references[0].type.to_s.must_equal 'EBE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_100').temporal_references[0].type.to_s.must_equal 'EBCW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_102').temporal_references[0].type.to_s.must_equal 'EBCWS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_104').temporal_references[0].type.to_s.must_equal 'EBS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_106').temporal_references[0].type.to_s.must_equal 'ECW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_108').temporal_references[0].type.to_s.must_equal 'ECWS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_110').temporal_references[0].type.to_s.must_equal 'EDU'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_112').temporal_references[0].type.to_s.must_equal 'OVERLAP'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_114').temporal_references[0].type.to_s.must_equal 'SAE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_116').temporal_references[0].type.to_s.must_equal 'SACWE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_118').temporal_references[0].type.to_s.must_equal 'SACW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_120').temporal_references[0].type.to_s.must_equal 'SAS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_122').temporal_references[0].type.to_s.must_equal 'SBE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_124').temporal_references[0].type.to_s.must_equal 'SBCWE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_126').temporal_references[0].type.to_s.must_equal 'SBCW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_128').temporal_references[0].type.to_s.must_equal 'SBS'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_130').temporal_references[0].type.to_s.must_equal 'SCW'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_132').temporal_references[0].type.to_s.must_equal 'SCWE'
    simple_xml_model.data_criteria('OccurrenceAInpatientEncounter1_precondition_134').temporal_references[0].type.to_s.must_equal 'SDU'
  end

end
