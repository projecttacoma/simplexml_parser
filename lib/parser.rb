module SimpleXml
  class Parser
    
    SIMPLEXML_VERSION_1 = "1.0"
    
    def self.parse(xml_contents, version, codes = nil)
      
      HQMF::Counter.instance.reset()
      case version
        when SIMPLEXML_VERSION_1
          SimpleXml::Document.new(xml_contents).to_model
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


  end
  
end