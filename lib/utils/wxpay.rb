require 'xmlsimple'

module Utils
  class Wxpay    

    #定义logger
    def self.logger
      Rails.logger
    end    

    #提交数据
    def self.post_xml_data(data,path)
        logger.debug("data:"+ data.to_s) 
        uri = URI.parse("https://api.mch.weixin.qq.com/")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Post.new(path)
        request.add_field('Content-Type', 'application/json')
        request.body = data
        response = http.request(request)
        logger.debug("body:"+ response.body) 
        result = XmlSimple.xml_in(response.body)
        logger.debug("result:"+result.to_s) 
        return result
     end

     def self.unifiedorder(params,key)
        path = "/pay/unifiedorder"
        data = "<xml>"
        params.each do |k,v|
          data += "<" + k.to_s + "><![CDATA[" + v.to_s + "]]></" + k.to_s + ">"          
        end
        data += "<sign><![CDATA[" + pay_sign(params,key) + "]]></sign>"
        data += "</xml>"
        result = post_xml_data(data,path)
        return result
     end

 
    #sign_string :appid, :appkey, :noncestr, :package, :timestamp
    def self.pay_sign(sign_params = {},key)
      #logger.debug(sign_params)
      result_string = ''
      sign_params = sign_params.sort
      sign_params.each{|key,value|
        result_string += (key.to_s + '=' + value.to_s + '&') unless value.blank?
      }
      result_string +="key=" + key
      sign = Digest::MD5.hexdigest(result_string).upcase
      sign
    end
  end
end
