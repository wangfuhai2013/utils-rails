module Utils
  class Common

	  def self.convert_bool(val)
	     ret = val
	     if ActiveRecord::Base.connection.adapter_name.downcase.starts_with? 'sqlite'
	       ret = "'t'" if val.to_i > 0
	       ret = "'f'" if val.to_i <= 0   
	     end
	     if ActiveRecord::Base.connection.adapter_name.downcase.starts_with? 'mysql'
	       ret = 1 if val == 't'
	       ret = 0 if val == 'f'   
	     end

	     ret
	  end  

  end
end
