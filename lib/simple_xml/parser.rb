module SimpleXml
  class Parser
    
    SIMPLEXML_VERSION_1 = "1.0"

    class V1Parser
      def initialize(*args)
      end

      def parse(xml_contents)
        HQMF::Counter.instance.reset()
        SimpleXml::Document.new(xml_contents).to_model
      end

      def version 
        SIMPLEXML_VERSION_1
      end


      def parse_fields(hqmf_contents)
        result = {}
        doc = SimpleXml::Document.parse(hqmf_contents)
        details = doc.at_xpath('measure/measureDetails')
        id = details.at_xpath('uuid').text.upcase
        set_id = details.at_xpath('guid').text.upcase
        version_number = details.at_xpath('version').text.to_i
        title = details.at_xpath('title').text
        description = details.at_xpath('description').text
        result = {'id' => id, 'set_id' => set_id, 'version' => version_number, 'title' => title, 'description' => description}
        result
      end

      def self.valid?(doc)
        !doc.at_xpath('measure/measureDetails').nil?
      end

    end
  end
  
end