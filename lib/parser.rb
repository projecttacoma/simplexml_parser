module SimpleXml
  class Parser
    
    SIMPLEXML_VERSION_1 = "1.0"
    
    def self.parse(xml_contents, version, codes = nil)
      
      HQMF::Counter.instance.reset()
      case version
        when SIMPLEXML_VERSION_1
          doc = SimpleXml::Document.new(xml_contents).to_model
          SimpleXml::Parser::backfill_patient_characteristics_with_codes(doc,codes)
          doc
        else
          raise "Unsupported SimpleXml version specified: #{version}"
      end
    end
    
    def self.parse_fields(hqmf_contents, version)
      result = {}
      case version
        when SIMPLEXML_VERSION_1
          doc = SimpleXml::Document.parse(hqmf_contents)

          details = doc.at_xpath('measure/measureDetails')
          id = details.at_xpath('uuid').text.upcase
          set_id = details.at_xpath('guid').text.upcase
          version_number = details.at_xpath('version').text.to_i
          title = details.at_xpath('title').text
          description = details.at_xpath('description').text

          result = {'id' => id, 'set_id' => set_id, 'version' => version_number, 'title' => title, 'description' => description}
        else
          raise "Unsupported HQMF version specified: #{version}"
      end
      result
    end

    def self.valid?(xml_contents)
      doc = Document.parse(xml_contents)
      !doc.at_xpath('measure/measureDetails').nil?
    end

    # patient characteristics data criteria such as GENDER require looking at the codes to determine if the 
    # measure is interested in Males or Females.  This process is awkward, and thus is done as a separate
    # step after the document has been converted.
    def self.backfill_patient_characteristics_with_codes(doc, codes)
      
      [].concat(doc.all_data_criteria).concat(doc.source_data_criteria).each do |data_criteria|
        if (data_criteria.type == :characteristic and !data_criteria.property.nil?)
          if (codes)
            value_set = codes[data_criteria.code_list_id]
            puts "\tno value set for unknown patient characteristic: #{data_criteria.id}" unless value_set
          else
            puts "\tno code set to back fill: #{data_criteria.title}"
            next
          end
          
          if (data_criteria.property == :gender)
            key = value_set.keys[0]
            data_criteria.value = HQMF::Coded.new('CD','Administrative Sex',value_set[key].first)
          else
            data_criteria.inline_code_list = value_set
          end
          
        elsif (data_criteria.type == :characteristic)
          if (codes)
            value_set = codes[data_criteria.code_list_id]
            if (value_set)
              # this is looking for a birthdate characteristic that is set as a generic characteristic but points to a loinc code set
              if (value_set['LOINC'] and value_set['LOINC'].first == '21112-8')
                data_criteria.definition = 'patient_characteristic_birthdate'
              end
              # this is looking for a gender characteristic that is set as a generic characteristic
              gender_key = (value_set.keys.select {|set| set == 'Administrative Sex' || set == 'AdministrativeSex'}).first
              if (gender_key and ['M','F'].include? value_set[gender_key].first)
                data_criteria.definition = 'patient_characteristic_gender'
                data_criteria.value = HQMF::Coded.new('CD','Gender',value_set[gender_key].first)
              end
            end
          end

        end
      end
    end
    
  end
  
end