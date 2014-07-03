require 'fileutils'
require 'digest'
require_relative '../test_helper'

class MissingOidsTest < Test::Unit::TestCase
  RESULTS_DIR = File.join('tmp','with_missing_oids')
  SIMPLE_XML_ROOT = File.join('test','fixtures','simplexml')

  # Create a blank folder for results
  FileUtils.rm_rf(RESULTS_DIR) if File.directory?(RESULTS_DIR)
  FileUtils.mkdir_p RESULTS_DIR

  def test_with_missing_oids
    simple_xml = File.join(SIMPLE_XML_ROOT, "with_missing_oids.xml")
    exception = assert_raises(RuntimeError) { SimpleXml::Parser::V1Parser.new.parse(File.read(simple_xml)) }
    assert_equal( "Found 2 QDM element(s) with missing oids: \n{\n  \"f3de96a4-3dbc-453e-b4ff-f23e96bee012\": \"Medication, Administered: Warfarin\",\n  \"2db28edc-9b4e-4f8b-ab03-d967c3889ff5\": \"Encounter, Performed: Inpatient\"\n}", exception.message )
  end

end
