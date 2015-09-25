module Utils
  class Common

	  def self.convert_bool(val)
	     ret = val
	     if ActiveRecord::Base.connection.adapter_name.downcase.starts_with? 'sqlite'
	       ret = "'t'" if val.to_i > 0
	       ret = "'f'" if val.to_i <= 0   
	     end
	     ret
	  end  

  end
end
