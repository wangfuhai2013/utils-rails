module Utils
  class Weixin    
    @@access_token_list = {}
    @@oauth2_access_token_list = {}

    #定义logger
    def self.logger
      Rails.logger
    end    

    #提交数据
    def self.post_data(data,path)
        logger.debug("data:"+ JSON.parse(data).to_s) 
        uri = URI.parse("https://api.weixin.qq.com/")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Post.new(path)
        request.add_field('Content-Type', 'application/json')
        request.body = data
        response = http.request(request)
        
        result = JSON.parse(response.body)
        logger.debug("result:"+result.to_s) 
        return result
     end

     #获取oauth2 url
     def self.get_oauth2_url(redirect_uri,auth_type,app_id=nil)
        app_id = Rails.configuration.weixin_app_id if app_id.nil?
        redirect_uri = CGI::escape(redirect_uri)
        
        state = 'oauth2'
        state = Rails.configuration.weixin_oauth2_state if Rails.configuration.respond_to?('weixin_oauth2_state')  
        url = "https://open.weixin.qq.com/connect/oauth2/authorize?" + 
              "appid=" + app_id + "&redirect_uri=" + redirect_uri + "&response_type=code" + 
              "&scope=" + auth_type + "&state=" + state + "#wechat_redirect"
        return url     
     end

     def self.get_oauth2_access_token(code,app_id=nil,app_secret=nil)
        app_id = Rails.configuration.weixin_app_id if app_id.nil?
        app_secret = Rails.configuration.weixin_app_secret if app_secret.nil?
        cache = @@oauth2_access_token_list[app_id]

        token = nil
        logger.debug("Utils::Weixin.get_access_token,cache access_token:"+cache.to_s)      
        if cache.nil? || cache[:expire_time].nil? || 
                         cache[:expire_time] - 600 < Time.now.to_i
           #提前十分钟过期，避免时间不同步导致时间差异

          return if code.blank? # 首次调用code为空时直接返回
 
          url = "https://api.weixin.qq.com/sns/oauth2/access_token"
          url += "?appid=" + app_id
          url += "&secret=" + app_secret
          url += "&code=" + code
          url += "&grant_type=authorization_code"

          conn = Faraday.new(:url => url,headers: { accept_encoding: 'none' })
          result = JSON.parse conn.get.body
          logger.debug("get oauth2_access_token result :"+result.to_s)
          if result['access_token']
            cache = {} if cache.nil?
            cache[:access_token] = result['access_token']
            cache[:expire_time] = Time.now.to_i + result['expires_in'].to_i
            token =  cache[:access_token]
            @@oauth2_access_token_list[app_id] = cache # 更新缓存
            logger.debug("Utils::Weixin.get_oauth2_access_token,access_token is update:"+cache[:access_token])
          else
            logger.error('Utils::Weixin.get_oauth2_access_token,获取access_token出错:' + result['errmsg'].to_s)
          end
       else
          token =  cache[:access_token]
       end
       return token       
     end

    #获取opendid，用于snsapi_base授权
    def self.get_openid(code,app_id=nil,app_secret=nil)
        openid,access_token = Utils::Weixin.get_openid_and_access_token(code,app_id,app_secret)
        return openid      
     end
     #同时获取openid和access_token,用于snsapi_userinfo授权
     def self.get_openid_and_access_token(code,app_id=nil,app_secret=nil)
        app_id = Rails.configuration.weixin_app_id if app_id.nil?
        app_secret = Rails.configuration.weixin_app_secret if app_secret.nil?
        path = "/sns/oauth2/access_token?appid=" + app_id + "&secret=" + app_secret + 
                "&code=" + code + "&grant_type=authorization_code"
        uri = URI.parse("https://api.weixin.qq.com/")
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        request = Net::HTTP::Get.new(path)
        request.add_field('Content-Type', 'application/json')
        response = http.request(request)        
        result = JSON.parse(response.body)
        logger.error("Utils::Weixin.get_openid fail,result:"+result.to_s) if result["openid"].blank?
        openid = access_token = nil
        openid = result["openid"] if result["openid"]
        access_token = result["access_token"] if result["access_token"]
        return openid,access_token      
     end

    #通过网页授权获取用户信息（无须关注公众号）
    def self.get_userinfo_by_auth(access_token,openid)
      url = "https://api.weixin.qq.com/sns/userinfo?access_token=" + access_token.to_s + 
            "&openid=" + openid.to_s + "&lang=zh_CN"
      conn = Faraday.new(:url => url)
      result = JSON.parse conn.get.body 
      if result["errmsg"]
         logger.error("Utils::Weixin.get_userinfo_by_auth of openid: "+ openid.to_s + 
                      ",access_token:" + access_token.to_s + ", error:" + result["errmsg"]) 
      end
      result
    end

    #获取用户信息（仅对关注者有效）
    def self.get_userinfo(openid,app_id=nil,app_secret=nil)
      app_id = Rails.configuration.weixin_app_id if app_id.nil?
      app_secret = Rails.configuration.weixin_app_secret if app_secret.nil?
      access_token = get_access_token(app_id,app_secret)
      url = "https://api.weixin.qq.com/cgi-bin/user/info?access_token=" + access_token + 
            "&openid=" + openid + "&lang=zh_CN"
      conn = Faraday.new(:url => url)
      result = JSON.parse conn.get.body 
      if result["errmsg"]
         logger.error("Utils::Weixin.get_userinfo of "+ openid.to_s + " error:" + result["errmsg"]) 
      end
      result
    end

     #获取基础access_token
     def self.get_access_token(app_id=nil,app_secret=nil)
        app_id = Rails.configuration.weixin_app_id if app_id.nil?
        app_secret = Rails.configuration.weixin_app_secret if app_secret.nil?
        cache = @@access_token_list[app_id]

        token = nil
        logger.debug("Utils::Weixin.get_access_token,cache access_token:"+cache.to_s)      
        if cache.nil? || cache[:expire_time].nil? || 
                         cache[:expire_time] - 600 < Time.now.to_i
           #提前十分钟过期，避免时间不同步导致时间差异

          url = "https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid="+
                app_id.to_s + "&secret=" + app_secret.to_s 
          result =JSON.parse(Net::HTTP.get(URI.parse(url)))
          logger.debug("get access_token result :"+result.to_s)
          if result['access_token']
            cache = {} if cache.nil?
            cache[:access_token] = result['access_token']
            cache[:expire_time] = Time.now.to_i + result['expires_in'].to_i
            token =  cache[:access_token]
            @@access_token_list[app_id] = cache # 更新缓存
            logger.debug("Utils::Weixin.get_access_token,access_token is update:"+cache[:access_token])
          else
            logger.error('Utils::Weixin.get_access_token,获取access_token出错:' + result['errmsg'].to_s)
          end
       else
          token =  cache[:access_token]
       end
       return token
     end

    #发送客服消息
    def self.send_customer_message(to_openid,message,app_id=nil,app_secret=nil)
      app_id = Rails.configuration.weixin_app_id if app_id.nil?
      app_secret = Rails.configuration.weixin_app_secret if app_secret.nil?
      access_token = get_access_token(app_id,app_secret)
      data = '{"touser":"'+ to_openid +'" , "msgtype": "text", "text": {"content": "' + 
               message + '"}}'                              
      path = '/cgi-bin/message/custom/send?access_token=' + access_token
      result = post_data(data,path)
      if result["errcode"] != 0
         logger.error("Utils::Weixin.send_customer_message to :"+to_openid + " result:" + result["errmsg"]) 
      end
    end

    #发送模板消息
    def self.send_template_message(to_openid,template_id,message,url='',top_color='#FF0000',value_color='#173177',
                                   app_id=nil,app_secret=nil)
      app_id = Rails.configuration.weixin_app_id if app_id.nil?
      app_secret = Rails.configuration.weixin_app_secret if app_secret.nil?
      access_token = get_access_token(app_id,app_secret)

      data = '{"touser":"'+ to_openid +'","template_id":"' + template_id +'","url":"' + url  + '",' +
              '"topcolor":"' + top_color + '","data":{'
      message.each do |m_k,m_v|
         data += '"' + m_k + '":{"value":"' + m_v + '","color":"' + value_color + '"},'         
      end
      data.chop! if data.end_with?(',')
      data += '}}'                 
      logger.debug("send_template_message data:" + data)         
      path = '/cgi-bin/message/template/send?access_token=' + access_token
      result = post_data(data,path)
      if result["errcode"] != 0
         logger.error("Utils::Weixin.send_template_message to :"+to_openid + " result:" + result["errmsg"]) 
      end
    end


    #sign_string :appid, :appkey, :noncestr, :package, :timestamp
    def self.pay_sign(sign_params = {},sign_type = 'SHA1')
      #logger.debug(sign_params)
      result_string = ''
      sign_params = sign_params.sort
      sign_params.each{|key,value|
        result_string += (key.to_s + '=' + value.to_s + '&')
      }
      logger.debug(result_string[0, result_string.length - 1])    
      sign = Digest::MD5.hexdigest(result_string[0, result_string.length - 1]).upcase if sign_type == 'MD5'
      sign = Digest::SHA1.hexdigest(result_string[0, result_string.length - 1]) if sign_type == 'SHA1'
      sign
    end

  end
end
