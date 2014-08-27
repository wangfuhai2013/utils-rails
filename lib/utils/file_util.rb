module Utils

  class FileUtil

    #定义logger
    def self.logger
      Rails.logger
    end    

    #获取预览图文件名
    def self.get_thumb_file(file_name)
       file_name[0..file_name.index('.')-1] +  "_thumb.jpg" unless file_name.index('.').nil?
    end
    #获取移动图片文件名
    def self.get_mobile_file(file_name)
       file_name[0..file_name.index('.')-1] +  "_mobile.jpg" unless file_name.index('.').nil?
    end  

    #删除文件
    def self.delete_file(file_name)
      if file_name
         full_name = Rails.root.join("public",file_name)
         #logger.debug("delete file:"+full_name.to_s)
         File.delete(full_name) if File.exist?(full_name)

         thumb_name = get_thumb_file(file_name)
         full_name = Rails.root.join("public",thumb_name) if thumb_name
         File.delete(full_name) if File.file?(full_name)

         mobile_name = get_mobile_file(file_name)
         full_name = Rails.root.join("public",mobile_name) if mobile_name
         File.delete(full_name) if File.file?(full_name)
      end
    end

    #检查文件上传许可
    def self.check_ext(res_file)
      if res_file
         extname = File.extname(res_file.original_filename)

         is_allowed_ext = false
         Rails.configuration.upload_extname.split(';').each do |ext| 
           if ext == extname
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
           abs_file_name = Rails.root.join("public",upload_path,file_name).to_s
           logger.debug("res_file:" + res_file.original_filename + ",abs_file_name:" + abs_file_name)
           #所有图片默认自动转成jpg格式，并且宽控制在720以内，压缩质量为80，以减小文件大小           
           max_width = 720
           max_width = Rails.configuration.image_max_width.to_i if Rails.configuration.respond_to?('image_max_width')
           max_width = width unless width == 0

           if File.extname(file_name) == '.jpg'
              resize_image_file(res_file.path,abs_file_name,max_width) 
           else             
             File.open(abs_file_name, 'wb') do |file|
                file.write(res_file.read)
             end
           end

           upload_path + "/" + file_name
       end
    end 

    #获取上传文件保存路径
    def self.get_upload_save_path
       upload_path = Rails.configuration.upload_path + "/"+ Time.now.strftime("%Y%m/%d")
       unless Dir.exist?(Rails.root.join("public",upload_path))
         FileUtils.mkdir_p(Rails.root.join("public",upload_path))
       end
       upload_path
    end

    #获取上传文件保存名称
    def self.get_upload_save_name(ori_filename,to_jpg=true)
       file_name_main = Time.now.to_i.to_s+Digest::SHA1.hexdigest(rand(9999).to_s)[0,6]
       file_name_ext =  File.extname(ori_filename)
       file_name_ext = ".jpg" if image_file?(ori_filename) && to_jpg
       file_name = file_name_main + file_name_ext
    end

    #缩小图片尺寸
    def self.resize_image_file(src_file,desc_file,max_width)
       image = MiniMagick::Image.open(src_file)

       if image[:width] > max_width
          image.resize max_width            
       end               
       image.format "jpg"
       image.quality "80"
       image.write desc_file
    end

    #检查是否图片文件名
    def self.image_file?(file_name)
       return !file_name.blank? && !!file_name.downcase.match("\\.png|\\.bmp|\\.jpeg|\\.jpg|\\.gif")
    end

    #生成缩略图
    def self.thumb_image(file_name,format="jpg",size="0")
       if image_file?(file_name)
         image = MiniMagick::Image.open(file_name)
         image.format format
         
         thumb_size = "300x300^" 
         thumb_size = Rails.configuration.image_thumb_size if Rails.configuration.respond_to?('image_thumb_size')    
         thumb_size = size unless size == "0"

         image.resize thumb_size
         #image.combine_options do |i|           
         #  i.resize "150x150^"
         #  i.gravity "center"
         #  i.crop "150x150+0+0"
         # end
         image.write  get_thumb_file(file_name)
       end
    end

    #生成手机图
    def self.mobile_image(file_name,format="jpg",size="0")
       if image_file?(file_name)
         image = MiniMagick::Image.open(file_name)
           image.format format
           
           mobile_size = "720x" 
           mobile_size = Rails.configuration.image_thumb_size if Rails.configuration.respond_to?('image_mobile_size')    
           mobile_size = size unless size == "0"

           image.resize mobile_size
           #image.combine_options do |i|           
           #  i.resize "150x150^"
           #  i.gravity "center"
           #  i.crop "150x150+0+0"
           # end
           image.write  get_mobile_file(file_name)
       end
    end

    #获取图片文件信息
    def self.get_image_info(file)
      path = file
      if !file.start_with?("/")
        path = Rails.root.join("public",file)
      end
      image = MiniMagick::Image.open(path)
      return image
    end
  end
end
