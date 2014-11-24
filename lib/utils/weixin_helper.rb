module Utils
  module WeixinHelper

    #调用微信接口获取openid，并设置在session中
    def set_session_openid(session_name='openid',app_id=nil,app_secret=nil)    
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
         openid = Utils::Weixin.get_openid(params[:code],app_id,app_secret)
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
        redirect_to Utils::Weixin.get_oauth2_url(request.original_url,'snsapi_base',app_id)
      end       
    end

      #获取oauth2 access_token，并设置实例变量
      def set_oauth2_access_token(app_id=nil,app_secret=nil)
        state = Rails.configuration.weixin_oauth2_state 
        if !params[:state].nil? && params[:state] == state && params[:code] #从授权接口返回
           @oauth2_access_token = Utils::Weixin.get_oauth2_access_token(params[:code],app_id,app_secret)  
           return
        end
        token = Utils::Weixin.get_oauth2_access_token("",app_id,app_secret)
        if token.nil?
          redirect_to Utils::Weixin.get_oauth2_url(request.original_url,'snsapi_base',app_id)
        else
          @oauth2_access_token = token
        end
      end

  end  
end