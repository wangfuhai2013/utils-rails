require 'utils/file_util'
require 'utils/sms'
require 'utils/weixin'
require 'utils/weixin_helper'
require 'utils/wxpay'
require 'utils/railtie' if defined?(Rails)

module Utils
end

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