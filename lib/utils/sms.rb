module Utils

  class Sms

    #定义logger
    def self.logger
      Rails.logger
    end    

    def self.send(mobile,message,provider='')
       provider = Rails.configuration.sms_provider if provider.blank? && Rails.configuration.respond_to?('sms_provider')
       result = false
       case provider
       when 'yunpian'
         result = send_by_yunpian(mobile,message)
       end
       result
    end
    def self.send_by_yunpian(mobile,message)
      result = false
      apikey = Rails.configuration.sms_apikey if Rails.configuration.respond_to?('sms_apikey')
      uri = URI.parse("http://yunpian.com/v1/sms/send.json")
      response = Net::HTTP.post_form(uri, {"apikey" => apikey,"mobile"=>mobile,"text"=>message})
      ret = JSON.parse(response.body)
      if ret["code"] == 0
        result = true
      end
      result
    end

    def self.send_verify_code(mobile,code,provider='')
       provider = Rails.configuration.sms_provider if provider.blank? && Rails.configuration.respond_to?('sms_provider')
       result = false
       case provider
       when 'yunpian'
         result = send_verify_code_by_yunpian(mobile,code)
       end
       result
    end  
    def self.send_verify_code_by_yunpian(mobile,code)
      result = false
      apikey = Rails.configuration.sms_apikey if Rails.configuration.respond_to?('sms_apikey')
      company = Rails.configuration.sms_company if Rails.configuration.respond_to?('sms_company')
      tpl_id = 1
      tpl_id = Rails.configuration.sms_tpl_id if Rails.configuration.respond_to?('tpl_id')
      tpl_value = "#code#=#{code}&#company#=#{company}"
      uri = URI.parse("http://yunpian.com/v1/sms/tpl_send.json")
      response = Net::HTTP.post_form(uri, {"apikey" => apikey,"mobile"=>mobile,
                                           "tpl_id"=>tpl_id,"tpl_value"=>tpl_value})
      ret = JSON.parse(response.body)
      logger.debug("send_verify_code_by_yunpian:" + ret.to_s)
      if ret["code"] == 0
        result = true
      end
      result
    end
  end
end
