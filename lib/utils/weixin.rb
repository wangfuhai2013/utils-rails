module HTTPResponseDecodeContentOverride
  def initialize(h,c,m)
    super(h,c,m)
    @decode_content = true
  end
  def body
    res = super
    if self['content-length']
      self['content-length']= res.bytesize
    end
    res
  end
end
module Net
  class HTTPResponse
    prepend HTTPResponseDecodeContentOverride
  end
end

module Utils
  class Weixin
    
    @@access_token_list = {}

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
        state = Rails.configuration.weixin_oauth2_state
        url = "https://open.weixin.qq.com/connect/oauth2/authorize?" + 
              "appid=" + app_id + "&redirect_uri=" + redirect_uri + "&response_type=code" + 
              "&scope=" + auth_type + "&state=" + state + "#wechat_redirect"
        return url     
     end

     #获取access_token
     def self.get_access_token(app_id=nil,secert=nil)
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

    #获取opendid
    def self.get_openid(code,app_id=nil,secert=nil)
        app_id = Rails.configuration.weixin_app_id if app_id.nil?
        app_secret = Rails.configuration.weixin_app_secret if app_secret.nil?
        path = "/sns/oauth2/access_token?appid=" + app_id + "&secret=" + secert + 
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
        openid = nil
        openid = result["openid"] if result["openid"]
        return openid      
     end

    #发送客服消息
    def self.send_message(to_openid,message,app_id=nil,secert=nil)
      app_id = Rails.configuration.weixin_app_id if app_id.nil?
      app_secret = Rails.configuration.weixin_app_secret if app_secret.nil?
      access_token = get_access_token(app_id,secert)
      data = '{"touser":"'+ to_openid +'" , "msgtype": "text", "text": {"content": "' + 
               message + '"}}'                              
      path = '/cgi-bin/message/custom/send?access_token=' + access_token
      result = post_weixin_data(data,path)
      if result["errcode"] != 0
         logger.error("Utils::Weixin.send_message to :"+to_openid + " result:" + result["errmsg"]) 
      end
    end

    #获取用户信息
    def self.get_userinfo(openid,app_id=nil,secert=nil)
      app_id = Rails.configuration.weixin_app_id if app_id.nil?
      app_secret = Rails.configuration.weixin_app_secret if app_secret.nil?
      access_token = get_access_token(app_id,secert)
      url = "https://api.weixin.qq.com/cgi-bin/user/info?access_token=" + access_token + 
            "&openid=" + openid + "&lang=zh_CN"
      conn = Faraday.new(:url => url)
      result = JSON.parse conn.get.body 
      if result["errmsg"]
         logger.error("Utils::Weixin.get_userinfo of "+ openid.to_s + " error:" + result["errmsg"]) 
      end
      result
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

     #设置session中的openid值
    def self.set_session_openid(params,session,return_url,session_name='openid')    
      #测试 start o6hyyjlRoyQelo6YgWstsRJjSBb8
      unless params[:openid].blank? 
        #TODO 校验是从微信传过来的参数才写入session；或者使用加密参数，用于没有网页授权接口权限的公众号
        #开发模式下才采用
        session[session_name] = params[:openid] if Rails.env == 'development' 
      end
      #logger.debug("session[:openid]:" + session[:openid] )
      #测试 end

      if !session[session_name].blank?
         return #已设置，直接返回
      end

      state = Rails.configuration.weixin_oauth2_state
      if !params[:state].nil? && params[:state] == state && params[:code] #从授权接口返回
         openid = get_openid(params[:code])
         if openid
           session[session_name] = openid
         else
           render text: "获取微信openid失败"
         end
      else
         render text: "微信接口返回参数错误(state,code)" if !params[:state].nil?
      end
      if params[:state].nil?
         #如果有state参数，表示从接口返回，不需再跳转
        redirect_to get_oauth2_url(return_url,'snsapi_base')
      end       
    end

  end
end
