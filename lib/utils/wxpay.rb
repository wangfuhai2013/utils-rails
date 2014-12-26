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

   #微信支付处理(JSAPI v2)
    def self.jsapi2(out_trade_no,total_fee,body,notify_url,openid,ip,app_id=nil,app_secret=nil,pay_sign_key=nil,mch_id=nil)

        app_id = Rails.configuration.weixin_app_id  if app_id.nil?
        app_secret = Rails.configuration.weixin_app_secret  if app_secret.nil?
        pay_sign_key= Rails.configuration.weixin_pay_sign_key  if pay_sign_key.nil?
        mch_id= Rails.configuration.weixin_mch_id if mch_id.nil?

        #构造支付订单接口参数
        pay_params = {
          :appid => app_id,
          :mch_id => mch_id,
          :body => body,           
          :nonce_str => Digest::MD5.hexdigest(Time.now.to_s).to_s,
          :notify_url => notify_url, #'http://szework.com/weixin/pay/notify',#get_notify_url(),
          :out_trade_no => out_trade_no, #out_trade_no, #'2014041311110001'
          :total_fee => total_fee, 
          :trade_type => 'JSAPI',   
          :openid =>  openid,
          :spbill_create_ip => ip #TODO 支持反向代理
        }

        pay_order = Utils::Wxpay.unifiedorder(pay_params,pay_sign_key)
        if pay_order["return_code"][0] == 'SUCCESS' && pay_order["result_code"][0] == 'SUCCESS'
          package_params = {
            :appId => app_id,
            :timeStamp => Time.now.to_i,
            :nonceStr => Digest::MD5.hexdigest(Time.now.to_s).to_s,
            :package => "prepay_id=" + pay_order["prepay_id"][0],
            :signType => "MD5" 
          }
          package_params[:paySign] = Utils::Wxpay.pay_sign(package_params,pay_sign_key)
        else         
           logger.info("one_weixin_pay.error:" + pay_order["return_msg"].to_s + ";" + 
               pay_order["err_code_des"].to_s )
           return nil
        end   
        return package_params       
    end

  end
end
