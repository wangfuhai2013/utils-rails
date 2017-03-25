module Utils

  class FileUtil

    #定义logger
    def self.logger
      Rails.logger
    end    

    def self.get_full_path(path,file_name="")         
      if Rails.configuration.respond_to?('upload_root') && !Rails.configuration.upload_root.blank?
        full_path = File.join(Rails.configuration.upload_root,path).to_s
      else
        full_path = Rails.root.join("public",path).to_s
      end
      full_path = File.join(full_path,file_name) unless file_name.blank?
      full_path
    end

    #获取预览图文件名
    def self.get_thumb_file(file_name,extname="")
       extname = File.extname(file_name) if extname.blank?
       extname = "." + extname if extname.index('.').nil?
       file_name[0..file_name.index('.')-1] +  "_thumb" + extname unless file_name.index('.').nil?
    end

    #获取移动图片文件名
    def self.get_mobile_file(file_name,extname="")
       extname = File.extname(file_name) if extname.blank?
       extname = "." + extname if extname.index('.').nil?
       file_name[0..file_name.index('.')-1] +  "_mobile" + extname unless file_name.index('.').nil?
    end  

    #删除文件
    def self.delete_file(file_name)
      unless file_name.blank?
         full_name = get_full_path(file_name)
         #logger.debug("delete file:"+full_name.to_s)
         File.delete(full_name) if File.exist?(full_name)

         thumb_name = get_thumb_file(file_name)
         full_name = get_full_path(thumb_name) if thumb_name
         File.delete(full_name) if File.file?(full_name)

         thumb_name = get_thumb_file(file_name,'jpg')
         full_name = get_full_path(thumb_name) if thumb_name
         File.delete(full_name) if File.file?(full_name)

         mobile_name = get_mobile_file(file_name)
         full_name = get_full_path(mobile_name) if mobile_name
         File.delete(full_name) if File.file?(full_name)

         mobile_name = get_mobile_file(file_name,'jpg')
         full_name = get_full_path(mobile_name) if mobile_name
         File.delete(full_name) if File.file?(full_name)

      end
    end


    #检查文件上传许可
    def self.check_ext(res_file)
      if res_file
         extname = File.extname(res_file.original_filename)

         is_allowed_ext = false
         Rails.configuration.upload_extname.split(';').each do |ext| 
           if ext.to_s.upcase == extname.to_s.upcase
              is_allowed_ext = true
              break
           end
         end
         #logger.debug("res_file: "+ is_allowed_ext.to_s)
         is_allowed_ext
      else
         true   #无文件返回true
      end
    end
    
    #上传文件
    def self.upload (res_file,to_jpg=true,width=0) # res_file为 ActionController::UploadedFile 对象
       if res_file
           upload_path = get_upload_save_path
           file_name   = get_upload_save_name(res_file.original_filename,to_jpg)

           abs_file_name = get_full_path(upload_path,file_name)
           logger.debug("res_file:" + res_file.original_filename + ",abs_file_name:" + abs_file_name)
                  
           max_width = 0
           max_width = Rails.configuration.image_max_width.to_i if Rails.configuration.respond_to?('image_max_width')
           max_width = width unless width == 0
           #只配置了image_max_width,才做图片缩小处理，jpg图质量统一使用80
           if image_file?(abs_file_name) && (to_jpg || max_width > 0)
              resize_image_file(res_file.path,abs_file_name,max_width) 
           else             
             File.open(abs_file_name, 'wb') do |file|
                file.write(res_file.read)
             end
           end

           upload_path + "/" + file_name
       end
    end 

    #从URL保存文件
    def self.save_from_url (url,to_jpg=false)       
        save_path  = get_upload_save_path + "/" + get_upload_save_name(url,to_jpg)
        save_path  += ".jpg" if to_jpg && File.extname(save_path).blank?
        conn = Faraday.new(:url => url)        
        File.open(get_full_path(save_path).to_s, 'wb') { |f| f.write(conn.get.body) }
        return save_path
    end

    #获取上传文件保存路径
    def self.get_upload_save_path
       upload_path = "upload"
       if Rails.configuration.respond_to?('upload_path') && !Rails.configuration.upload_path.blank?
         upload_path = Rails.configuration.upload_path
       end
       upload_path += "/"+ Time.now.strftime("%Y%m/%d")
       unless Dir.exist?(get_full_path(upload_path))
         FileUtils.mkdir_p(get_full_path(upload_path))
       end
       upload_path
    end

    #获取上传文件保存名称
    def self.get_upload_save_name(ori_filename,to_jpg=true)
       file_name_main = (Time.now.to_f * 1000000).to_i.to_s(16) + Digest::SHA2.hexdigest(rand.to_s)[0,8]
       file_name_ext =  File.extname(ori_filename).downcase #扩展名统一小写
       file_name_ext = ".jpg" if image_file?(ori_filename) && to_jpg
       file_name = file_name_main + file_name_ext
    end

    #缩小图片尺寸
    def self.resize_image_file(src_file,dst_file="",max_width=0)
       return unless File.exist?(src_file)
       image = MiniMagick::Image.open(src_file)
       dst_file = src_file if dst_file.blank?
       if image[:width] > max_width && max_width > 0
          image.resize max_width.to_s + "x"            
       end
       if File.extname(dst_file) == '.jpg'
         image.format "jpg"
         image.quality "80"                        
       end               
       image.write dst_file
       File.chmod(0644,dst_file) # MiniMagick没有处理图片(resize或format）而直接写文件时，默认把文件权限设为600
    end

    #检查是否图片文件名
    def self.image_file?(file_name)
       return !file_name.blank? && !!file_name.downcase.match("\\.png|\\.bmp|\\.jpeg|\\.jpg|\\.gif")
    end

    #生成缩略图
    def self.thumb_image(file_name,format="jpg",size="0")
      thumb_size = "300x" 
      thumb_size = Rails.configuration.image_thumb_size if Rails.configuration.respond_to?('image_thumb_size')    
      thumb_size = size.to_s  unless size == "0"

      resize_image(file_name,get_thumb_file(file_name),thumb_size)
      resize_image(file_name,get_thumb_file(file_name,format),thumb_size) if File.extname(file_name).downcase.sub(".","") != format
    end

    #生成手机图
    def self.mobile_image(file_name,format="jpg",size="0")         
       mobile_size = "720x" 
       mobile_size = Rails.configuration.image_thumb_size if Rails.configuration.respond_to?('image_mobile_size')    
       mobile_size = size.to_s  unless size == "0"

       resize_image(file_name,get_mobile_file(file_name),thumb_size)
       resize_image(file_name,get_mobile_file(file_name,format),thumb_size) if File.extname(file_name).downcase.sub(".","") != format
    end

    #内部方法，不对外
    def self.resize_image(src_file,dst_file,size)   
       #logger.debug(src_file + "," + dst_file + "," + size)    
       src_file = get_full_path(src_file)  if !src_file.start_with?("/")
       dst_file = get_full_path(dst_file)  if !dst_file.start_with?("/")      
       if image_file?(src_file) &&  File.exist?(src_file)
         image = MiniMagick::Image.open(src_file)
         size += "x" if !!(size =~ /\A[0-9]+\z/)  # 如果只设置一个数字，则默认为宽
         size += ">" if size.index(">").nil? && size.index("<").nil? && size.index("^").nil?  # 默认不放大，只缩小
         #logger.debug(src_file + "," + dst_file + "," + size)
         image.resize size
         src_ext = File.extname(src_file).downcase.sub(".","")
         dst_ext = File.extname(dst_file).downcase.sub(".","")
         if src_ext != dst_ext
           image.format dst_ext
           image.quality "80" if dst_ext == 'jpg'                       
         end               

         #image.combine_options do |i|           
         #  i.resize "150x150^"
         #  i.gravity "center"
         #  i.crop "150x150+0+0"
         # end
         image.write  dst_file
       end      
    end

    #获取图片文件信息
    def self.get_image_info(file_name)
      file_name = get_full_path(file_name)  if !file_name.start_with?("/")
      image = MiniMagick::Image.open(file_name)
      return image
    end

  end
end