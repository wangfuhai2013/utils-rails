require 'utils/common'
require 'utils/file_util'
require 'utils/sms'
require 'utils/weixin'
require 'utils/weixin_helper'
require 'utils/wxpay'
require 'utils/railtie' if defined?(Rails)

module Utils

end

class String
  def to_bool
    return true if self == true || self =~ (/^(true|t|yes|y|1)$/i)
    return false if self == false || self.blank? || self =~ (/^(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end

class Fixnum
  def to_bool
    return true if self == 1
    return false if self == 0
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end

class TrueClass
  def to_i; 1; end
  def to_bool; self; end
end

class FalseClass
  def to_i; 0; end
  def to_bool; self; end
end

class NilClass
  def to_bool; false; end
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