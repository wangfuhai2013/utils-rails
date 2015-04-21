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

     #微信支付处理(NATIVE)
     def self.native(out_trade_no,total_fee,body,notify_url,openid,ip,return_code=true,app_id=nil,mch_id=nil,pay_sign_key=nil)
        result =  Utils::Wxpay.unifiedorder('NATIVE',out_trade_no,total_fee,body,notify_url,openid,ip,app_id,mch_id,pay_sign_key)
        return nil if result.nil?

        if return_code 
          return result["code_url"][0] #模式二返回结果
        else
          package_params = {
            :appId => app_id,
            :timeStamp => Time.now.to_i.to_s,#必须是字符串，否则iPhone下报错
            :nonceStr => Digest::MD5.hexdigest(Time.now.to_s).to_s,
            :package => "prepay_id=" + result["prepay_id"][0],
            :signType => "MD5" 
          }
          package_params[:paySign] = Utils::Wxpay.pay_sign(package_params,pay_sign_key)
          return package_params   #模式一返回结果
        end 
     end

     #微信支付处理(JSAPI v2)
     def self.jsapi2(out_trade_no,total_fee,body,notify_url,openid,ip,app_id=nil,mch_id=nil,pay_sign_key=nil)
        return Utils::Wxpay.unifiedorder('JSAPI',out_trade_no,total_fee,body,notify_url,openid,ip,app_id,mch_id,pay_sign_key)
     end

     #微信支付统一调用接口
     def self.unifiedorder(trade_type,out_trade_no,total_fee,body,notify_url,openid,ip,app_id,mch_id,pay_sign_key)
        app_id = Utils::Weixin.app_id  if app_id.nil?        
        pay_sign_key= Utils::Weixin.pay_sign_key  if pay_sign_key.nil?
        mch_id= Utils::Weixin.mch_id if mch_id.nil?

        #构造支付订单接口参数
        pay_params = {
          :appid => app_id,
          :mch_id => mch_id,
          :body => body,           
          :nonce_str => Digest::MD5.hexdigest(Time.now.to_s).to_s,
          :notify_url => notify_url, #'http://szework.com/weixin/pay/notify',#get_notify_url(),
          :out_trade_no => out_trade_no, #out_trade_no, #'2014041311110001'
          :total_fee => total_fee, 
          :trade_type => trade_type,   
          :openid =>  openid,
          :spbill_create_ip => ip #TODO 支持反向代理
        }
        
        path = "/pay/unifiedorder"
        data = "<xml>"
        pay_params.each do |k,v|
          data += "<" + k.to_s + "><![CDATA[" + v.to_s + "]]></" + k.to_s + ">"          
        end
        data += "<sign><![CDATA[" + pay_sign(pay_params,pay_sign_key) + "]]></sign>"
        data += "</xml>"
        result = post_xml_data(data,path)
        if result["return_code"][0] == 'SUCCESS' && result["result_code"][0] == 'SUCCESS'
          #JSAPI调用返回
          if result["trade_type"][0] == 'JSAPI'
            package_params = {
              :appId => app_id,
              :timeStamp => Time.now.to_i.to_s,#必须是字符串，否则iPhone下报错
              :nonceStr => Digest::MD5.hexdigest(Time.now.to_s).to_s,
              :package => "prepay_id=" + result["prepay_id"][0],
              :signType => "MD5" 
            }
            package_params[:paySign] = Utils::Wxpay.pay_sign(package_params,pay_sign_key)
            return package_params          
          end

          #NATIVE调用返回        
          return result
        else         
          #调用失败
           logger.info("weixin_pay.error:" + result["return_msg"].to_s + ";" + 
               result["err_code_des"].to_s )
           return nil
        end    
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
